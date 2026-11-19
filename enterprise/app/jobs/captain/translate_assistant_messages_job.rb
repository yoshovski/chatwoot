class Captain::TranslateAssistantMessagesJob < ApplicationJob
  queue_as :default

  class GenerationUnavailable < StandardError; end

  retry_on GenerationUnavailable, wait: :polynomially_longer, attempts: 3

  def perform(assistant_id)
    assistant = Captain::Assistant.find_by(id: assistant_id)
    return unless assistant

    messages = Captain::LocalizedMessages.new(assistant.config)
    pending = messages.generation_inputs.reject { |locale, field, _| messages.generated_text(field, locale) }
    outcomes = pending.group_by(&:first).map { |locale, fields| translate(assistant, messages, locale, fields) }
    raise GenerationUnavailable if outcomes.include?(false)
  end

  private

  def translate(assistant, messages, locale, fields)
    sources = fields.index_with { |_, field, _| messages.source(field) }.transform_keys { |_, field, _| field }
    translated = Captain::Llm::MessageTranslationService.new(account: assistant.account, source_messages: sources, locale: locale).perform
    return false unless translated

    valid = fields.select do |_, field, _|
      draft = translated[field]
      Captain::LocalizedMessages.valid_translation?(sources[field], draft) && !Captain::Conversation::CustomerLocale.mismatch?(draft, locale)
    end
    persist(assistant, locale, valid, translated) if valid.any?
    valid.size == fields.size
  end

  def persist(assistant, locale, fields, translated)
    assistant.with_lock do
      messages = Captain::LocalizedMessages.new(assistant.config)
      current = (fields & messages.generation_inputs).reject { |_, field, _| messages.generated_text(field, locale) }
      next if current.empty?

      config = assistant.config.deep_dup
      generated = (config['generated_localized_messages'] ||= {})
      current.each do |_, field, revision|
        (generated[field] ||= {})[locale] = { 'revision' => revision, 'text' => translated.fetch(field) }
      end
      assistant.update!(config: config)
    end
  end
end

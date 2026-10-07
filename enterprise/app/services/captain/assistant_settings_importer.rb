# Applies a client's assistant settings from a JSON export, so client prompts, rules,
# scenarios and FAQ replies live outside the codebase. Re-running it updates in place.
#
# Shape: { "description", "response_guidelines" [], "guardrails" [], "config" {},
#          "scenarios" [{ "title", "description", "instruction" }], "responses" [{ "question", "answer" }] }
# Allowlists in "config" are added to the store's default allowlists.
class Captain::AssistantSettingsImporter
  ALLOWLIST_KEYS = %w[link_allowlist image_allowlist].freeze

  def self.apply!(assistant:, settings:)
    new(assistant: assistant, settings: settings).apply!
  end

  def initialize(assistant:, settings:)
    @assistant = assistant
    @settings = settings
  end

  def apply!
    ActiveRecord::Base.transaction do
      update_assistant!
      import_scenarios!
      import_responses!
    end
    assistant
  end

  private

  attr_reader :assistant, :settings

  def update_assistant!
    config = assistant.config.to_h.merge(settings.fetch('config'))
    ALLOWLIST_KEYS.each do |key|
      config[key] = (assistant.public_send("default_#{key}") + config[key]).uniq if config[key].present?
    end

    assistant.update!(
      description: settings.fetch('description'),
      response_guidelines: settings.fetch('response_guidelines'),
      guardrails: settings.fetch('guardrails'),
      config: config
    )
  end

  def import_scenarios!
    settings.fetch('scenarios', []).each do |data|
      scenario = assistant.scenarios.find_or_initialize_by(title: data.fetch('title'))
      scenario.update!(account: assistant.account, description: data.fetch('description'), instruction: data.fetch('instruction'), enabled: true)
    end
  end

  def import_responses!
    settings.fetch('responses', []).each do |data|
      response = assistant.responses.find_or_initialize_by(question: data.fetch('question'))
      response.update!(account: assistant.account, answer: data.fetch('answer'), status: :approved)
    end
  end
end

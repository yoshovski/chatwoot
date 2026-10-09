# frozen_string_literal: true

class Captain::Conversation::OutcomeLabelJob < ApplicationJob
  queue_as :low

  def perform(conversation, assistant = nil)
    @conversation = conversation
    @account = conversation&.account
    @assistant = assistant || conversation&.inbox&.captain_assistant

    return unless may_perform?

    transcript = Captain::Conversation::TranscriptBuilder.new(@conversation).build
    return if transcript.blank?

    outcome = Captain::Llm::OutcomeClassifierService.new(
      assistant: @assistant,
      conversation: @conversation
    ).classify(transcript)

    apply_outcome_label(outcome) if outcome.present?
  end

  private

  def may_perform?
    return false if @conversation.blank? || @assistant.blank?
    return false unless @account.feature_enabled?('captain_integration_v2')
    return false unless @assistant.outcome_labels?
    return false unless captain_responses_left?

    true
  end

  def captain_responses_left?
    @account.usage_limits.dig(:captain, :responses, :current_available).to_i.positive?
  end

  def apply_outcome_label(chosen_outcome)
    current_labels = @conversation.label_list
    labels_to_remove = Captain::Llm::OutcomeClassifierService::OUTCOMES + ['needs-human']
    updated_labels = (current_labels - labels_to_remove) + [chosen_outcome]

    @account.labels.find_or_create_by!(title: chosen_outcome)
    Current.executed_by = @assistant
    @conversation.update_labels(updated_labels)
  ensure
    Current.executed_by = nil
  end
end

class Captain::Conversation::OwnershipService
  HUMAN_ACTIVE_LABEL = 'human-active'.freeze
  WAITING_INSTRUCTION = 'A human handoff is already active, but no human has replied publicly yet. ' \
                        'Continue helping with answerable questions. Don\'t hand off again or promise a response time. ' \
                        'If asked when someone will answer, say the team has been notified and the customer may keep sending details.'.freeze
  RETURNED_TO_AI_INSTRUCTION = 'A previous human handoff is complete; continue naturally.'.freeze

  attr_reader :conversation, :assistant

  def initialize(conversation:, assistant: nil)
    @conversation = conversation
    @assistant = assistant || conversation&.inbox&.captain_assistant
  end

  def may_reply?
    return false unless eligible_state?

    conversation.pending? || waiting?
  end

  def waiting?
    return false unless eligible_state?
    return false unless conversation.open?
    return false unless continue_while_waiting?

    !human_taken_over?
  end

  def prompt_instruction
    if waiting?
      WAITING_INSTRUCTION
    elsif returned_to_ai?
      RETURNED_TO_AI_INSTRUCTION
    end
  end

  def human_taken_over?
    return false if conversation.blank?

    human_active_label? || human_public_reply?
  end

  def human_active_label?
    labels = conversation.label_list.to_a
    labels.include?(HUMAN_ACTIVE_LABEL) || conversation.cached_label_list_array.include?(HUMAN_ACTIVE_LABEL)
  end

  def human_public_reply?
    since_time = returned_to_ai_at || conversation.status_changed_at || conversation.created_at
    conversation.messages
                .where(message_type: :outgoing, private: false, sender_type: 'User')
                .exists?(['messages.created_at >= ?', since_time])
  end

  def record_human_takeover!
    return if conversation.blank? || assistant.blank?
    return unless captain_configured_for_inbox?
    return unless continue_while_waiting?
    return unless conversation.open?
    return if human_active_label?

    conversation.add_labels(HUMAN_ACTIVE_LABEL)
  end

  def handle_returned_to_ai!
    return if conversation.blank? || assistant.blank?
    return unless captain_configured_for_inbox?

    clear_human_active_label!
    set_returned_to_ai_flag!
  end

  def handle_resolved!
    return if conversation.blank?

    clear_human_active_label!
    clear_returned_to_ai_attributes!
  end

  def returned_to_ai?
    return false if conversation.blank?

    custom_attributes['captain_returned_to_ai'] == true
  end

  def clear_returned_to_ai_flag!
    return if conversation.blank?
    return unless custom_attributes.key?('captain_returned_to_ai')

    attrs = custom_attributes.dup
    attrs.delete('captain_returned_to_ai')
    conversation.update!(custom_attributes: attrs)
  end

  def clear_returned_to_ai_attributes!
    return if conversation.blank?
    return unless custom_attributes.key?('captain_returned_to_ai') || custom_attributes.key?('captain_returned_to_ai_at')

    attrs = custom_attributes.dup
    attrs.delete('captain_returned_to_ai')
    attrs.delete('captain_returned_to_ai_at')
    conversation.update!(custom_attributes: attrs)
  end

  private

  def eligible_state?
    return false if conversation.blank? || assistant.blank?
    return false unless captain_configured_for_inbox?
    return false if conversation.resolved? || conversation.snoozed?

    true
  end

  def continue_while_waiting?
    assistant.continue_while_waiting?
  end

  def captain_configured_for_inbox?
    inbox = conversation.inbox
    return true if inbox.blank? || (inbox.captain_inbox.blank? && inbox.captain_assistant.blank?)

    inbox.captain_inbox&.captain_assistant_id == assistant.id || inbox.captain_assistant == assistant
  end

  def custom_attributes
    conversation.custom_attributes.is_a?(Hash) ? conversation.custom_attributes : {}
  end

  def returned_to_ai_at
    timestamp = custom_attributes['captain_returned_to_ai_at']
    Time.zone.parse(timestamp) if timestamp.present?
  rescue StandardError
    nil
  end

  def set_returned_to_ai_flag!
    attrs = custom_attributes.dup
    attrs['captain_returned_to_ai'] = true
    attrs['captain_returned_to_ai_at'] = Time.current.iso8601
    conversation.update!(custom_attributes: attrs)
  end

  def clear_human_active_label!
    current_labels = conversation.label_list.to_a
    return unless current_labels.include?(HUMAN_ACTIVE_LABEL)

    conversation.update_labels(current_labels - [HUMAN_ACTIVE_LABEL])
  end
end

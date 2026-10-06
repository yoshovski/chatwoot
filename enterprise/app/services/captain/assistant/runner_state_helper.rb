module Captain::Assistant::RunnerStateHelper
  CONVERSATION_STATE_ATTRIBUTES = %i[
    id display_id inbox_id contact_id status priority
    label_list custom_attributes additional_attributes
  ].freeze

  CONTACT_STATE_ATTRIBUTES = %i[
    id name email phone_number identifier contact_type
    custom_attributes additional_attributes
  ].freeze

  CONTACT_INBOX_STATE_ATTRIBUTES = %i[id hmac_verified].freeze

  CAMPAIGN_STATE_ATTRIBUTES = %i[id title message campaign_type description].freeze

  private

  def build_state
    state = {
      account_id: @assistant.account_id,
      assistant_id: @assistant.id,
      assistant_config: @assistant.config,
      timezone: @conversation&.inbox&.timezone.presence || 'UTC'
    }
    state[:source] = @source if @source.present?
    state[:responding_to_message_id] = @responding_to_message_id if @responding_to_message_id.present?

    build_conversation_state(state) if @conversation
    state
  end

  def build_conversation_state(state)
    state[:conversation] = slice_attrs(@conversation, CONVERSATION_STATE_ATTRIBUTES)
    state[:conversation][:label_list] = @conversation.label_list.to_a
    state[:channel_type] = @conversation.inbox&.channel_type
    state[:message_length_limit] = Captain::MessageLengthLimit.for(@conversation)
    enrich_associated_state!(state)
    state[:ownership_instruction] = ownership_instruction
  end

  def enrich_associated_state!(state)
    state[:contact] = slice_attrs(@conversation.contact, CONTACT_STATE_ATTRIBUTES) if @conversation.contact
    state[:campaign] = slice_attrs(@conversation.campaign, CAMPAIGN_STATE_ATTRIBUTES) if @conversation.campaign
    state[:contact_inbox] = slice_attrs(@conversation.contact_inbox, CONTACT_INBOX_STATE_ATTRIBUTES) if @conversation.contact_inbox
  end

  def ownership_instruction
    ownership_service.prompt_instruction if respond_to?(:ownership_service, true)
  end

  def slice_attrs(record, keys)
    record.attributes.symbolize_keys.slice(*keys)
  end
end

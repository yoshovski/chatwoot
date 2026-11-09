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
      timezone: @conversation&.inbox&.timezone.presence || 'UTC',
      suggested_replies_enabled: suggested_replies_enabled?,
      max_suggested_replies: @assistant.max_suggested_replies,
      product_cards_enabled: product_cards_enabled?,
      commerce_enabled: commerce_enabled?
    }
    state[:source] = @source if @source.present?
    state[:responding_to_message_id] = @responding_to_message_id if @responding_to_message_id.present?

    build_conversation_state(state) if @conversation
    state
  end

  def build_conversation_state(state)
    state[:lead_intake] = Captain::Leads::CaptureState.new(@assistant, @conversation).prompt_context if @assistant.leads_enabled?
    state[:lead_questions_remaining] = Captain::Leads::QuestionBudget.new(@assistant, @conversation).remaining if @assistant.leads_enabled?
    state[:conversation] = slice_attrs(@conversation, CONVERSATION_STATE_ATTRIBUTES)
    state[:conversation][:label_list] = @conversation.label_list.to_a
    state[:channel_type] = @conversation.inbox&.channel_type
    state[:message_length_limit] = Captain::MessageLengthLimit.for(@conversation)
    enrich_associated_state!(state)
    state[:ownership_instruction] = ownership_instruction
    state[:handoff_tool_disabled] = handoff_tool_disabled?
  end

  def enrich_associated_state!(state)
    state[:website_activity] = @conversation.contact_inbox&.website_activity || {}
    state[:contact] = slice_attrs(@conversation.contact, CONTACT_STATE_ATTRIBUTES) if @conversation.contact
    state[:campaign] = slice_attrs(@conversation.campaign, CAMPAIGN_STATE_ATTRIBUTES) if @conversation.campaign
    state[:contact_inbox] = slice_attrs(@conversation.contact_inbox, CONTACT_INBOX_STATE_ATTRIBUTES) if @conversation.contact_inbox
    state[:visitor_history] = visitor_history if @conversation.contact
  end

  # Earlier conversations of this contact in this inbox, for the returning-visitor line of the visitor context.
  def visitor_history
    earlier = ::Conversation.where(contact_id: @conversation.contact_id, inbox_id: @conversation.inbox_id).where.not(id: @conversation.id)
    { earlier_conversations: earlier.count, last_conversation_status: earlier.order(:created_at).last&.status }
  end

  # The agent greets only when nothing was said to the customer yet: no earlier reply and no campaign opener.
  def first_ai_reply?(history)
    return false if reply_suggestion? || !Captain::Behaviour::WELCOME_ON_FIRST_REPLY

    @conversation&.campaign_id.blank? && history.none? { |entry| entry[:role] == :assistant }
  end

  # Set by build_context, which runs before the agents and their reply schema are built.
  def ai_welcome? = @first_ai_reply == true

  def ownership_instruction
    return unless respond_to?(:ownership_service, true)

    # While a handoff already waits for a colleague, only the ownership state applies.
    policy = handoff_policy.prompt_instruction unless ownership_service.waiting?
    [ownership_service.prompt_instruction, policy].compact.join("\n").presence
  end

  def handoff_tool_disabled?
    (respond_to?(:waiting_for_human?, true) && waiting_for_human?) ||
      (respond_to?(:handoff_kept?, true) && handoff_kept?)
  end

  def slice_attrs(record, keys)
    record.attributes.symbolize_keys.slice(*keys)
  end

  def commerce_enabled?
    @assistant.commerce_enabled?
  end
end

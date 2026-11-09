# Sends one check-in per quiet period to pending conversations where the agent spoke last.
# Runs from the resolution job before auto-resolve, also when auto-resolve is off. All state comes from messages.
class Captain::Conversation::CheckInRunner
  def initialize(inbox:, assistant:)
    @inbox = inbox
    @assistant = assistant
  end

  # Returns the ids of the conversations that got a check-in in this run.
  def perform
    return [] unless @assistant.account.feature_enabled?('captain_integration_v2')

    candidates.filter_map { |conversation| conversation.id if check_in(conversation) }
  end

  def self.check_in_after(assistant) = Captain::Behaviour.check_in_after_minutes(assistant).minutes

  def self.proactive_check_in_delay(assistant, conversation)
    if conversation&.inbox&.web_widget?
      state = Captain::Conversation::CheckInState.new(conversation: conversation, assistant: assistant)
      seconds = if state.awaiting_customer_answer?
                  Captain::Behaviour.widget_check_in_awaiting_seconds(assistant)
                else
                  Captain::Behaviour.widget_check_in_completed_seconds(assistant)
                end
      return seconds.seconds
    end

    check_in_after(assistant)
  end

  # Auto-resolve waits for a prospect's lead offer while the runner can still send it.
  def self.awaiting_lead_offer?(conversation, assistant)
    return false unless assistant.leads_enabled?
    return false if conversation.last_activity_at < Captain::Behaviour::CHECK_IN_LOOKBACK.ago

    state = Captain::Conversation::CheckInState.new(conversation: conversation, assistant: assistant)
    state.assistant_spoke_last? && state.lead_guard?
  end

  # A failing check-in never stops the other conversations or the resolution that follows.
  def check_in(conversation, proactive: false)
    return false unless eligible?(conversation, proactive: proactive)

    # A prospect's first check-in is a lead offer; when follow-up isn't appropriate, a plain check-in marks the offer skipped.
    if check_in_state(conversation).lead_guard?
      return emitted(conversation, Captain::Conversation::CheckInState::LEAD_OFFER) if offer_lead(conversation, proactive: proactive)

      lead_offer_skipped = true
    end
    post_check_in(conversation, lead_offer_skipped: lead_offer_skipped, proactive: proactive)
  rescue ActiveRecord::RecordNotFound
    false
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: conversation.account).capture_exception
    false
  end

  private

  def candidates
    now = Time.current
    @inbox.conversations.pending
          .where(last_activity_at: (now - Captain::Behaviour::CHECK_IN_LOOKBACK)...cutoff_time(now))
          .where.not(id: checked_in_conversation_ids)
          .reorder(last_activity_at: :asc)
          .limit(Limits::BULK_ACTIONS_LIMIT)
  end

  def cutoff_time(now = Time.current, conversation: nil)
    delay = conversation ? self.class.proactive_check_in_delay(@assistant, conversation) : self.class.check_in_after(@assistant)
    now - delay
  end

  # Conversations whose latest check-in came after the visitor's last message: this quiet period is covered.
  def checked_in_conversation_ids
    Message.outgoing.where(inbox_id: @inbox.id, sender: @assistant)
           .where('messages.additional_attributes ? :key', key: Captain::Conversation::CheckInState::ATTRIBUTE_KEY)
           .where(created_at: Captain::Behaviour::CHECK_IN_LOOKBACK.ago..)
           .where.not('EXISTS (SELECT 1 FROM messages later WHERE later.conversation_id = messages.conversation_id ' \
                      'AND later.message_type = 0 AND later.id > messages.id)')
           .select(:conversation_id)
  end

  def offer_lead(conversation, proactive: false)
    service = Captain::Conversation::LeadOfferService.new(conversation: conversation, assistant: @assistant)
    proposal = service.proposal
    return false unless proposal

    post_locked(conversation, proactive: proactive) { service.deliver!(proposal) if check_in_state(conversation).lead_guard? }.present?
  end

  def post_check_in(conversation, lead_offer_skipped:, proactive: false)
    content = Captain::Conversation::CheckInService.new(conversation: conversation, assistant: @assistant).perform
    attributes = { 'agent_name' => @assistant.agent_name,
                   Captain::Conversation::CheckInState::ATTRIBUTE_KEY => Captain::Conversation::CheckInState::CHECK_IN }
    attributes[Captain::Conversation::CheckInState::LEAD_OFFER_SKIPPED_KEY] = true if lead_offer_skipped
    message = post_locked(conversation, proactive: proactive) do
      conversation.messages.create!(
        content: content, content_type: 'text', message_type: :outgoing, account_id: conversation.account_id,
        inbox_id: conversation.inbox_id, sender: @assistant, preserve_waiting_since: true, additional_attributes: attributes
      )
    end
    message ? emitted(conversation, Captain::Conversation::CheckInState::CHECK_IN) : false
  end

  # Model calls happen outside the lock; inside it the conversation is reloaded and checked again,
  # so two overlapping runs send one check-in.
  def post_locked(conversation, proactive: false)
    conversation.with_lock do
      conversation.reload
      next unless eligible?(conversation, proactive: proactive)

      yield
    end
  end

  def eligible?(conversation, proactive: false)
    return false unless quiet_enough?(conversation, proactive: proactive)

    state = check_in_state(conversation)
    return false unless state.assistant_spoke_last? && agent_may_reply?(conversation)
    return false if waiting_on_form?(conversation, state)

    !state.checked_in_this_quiet_period?
  end

  def quiet_enough?(conversation, proactive:)
    cutoff = proactive ? (cutoff_time(Time.current, conversation: conversation) + 2.seconds) : cutoff_time
    conversation.pending? && conversation.last_activity_at <= cutoff
  end

  def waiting_on_form?(conversation, state)
    state.last_public_message.content_type == 'form' ||
      Captain::Leads::FollowupFormService.new(@assistant, conversation).pending?
  end

  def check_in_state(conversation) = Captain::Conversation::CheckInState.new(conversation: conversation, assistant: @assistant)

  def agent_may_reply?(conversation)
    ownership = Captain::Conversation::OwnershipService.new(conversation: conversation, assistant: @assistant)
    ownership.may_reply? && !ownership.waiting?
  end

  def emitted(conversation, kind)
    Captain::ConversationEvents.checked_in(conversation: conversation, assistant: @assistant, kind: kind, at: Time.current)
    true
  end
end

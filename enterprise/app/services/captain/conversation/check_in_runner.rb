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

  private

  def candidates
    now = Time.current
    @inbox.conversations.pending
          .where(last_activity_at: (now - Captain::Behaviour::CHECK_IN_LOOKBACK)...cutoff_time(now))
          .where.not(id: checked_in_conversation_ids)
          .reorder(last_activity_at: :asc)
          .limit(Limits::BULK_ACTIONS_LIMIT)
  end

  def cutoff_time(now = Time.current) = now - self.class.check_in_after(@assistant)

  # Conversations whose latest check-in came after the visitor's last message: this quiet period is covered.
  def checked_in_conversation_ids
    Message.outgoing.where(inbox_id: @inbox.id, sender: @assistant)
           .where('messages.additional_attributes ? :key', key: Captain::Conversation::CheckInState::ATTRIBUTE_KEY)
           .where(created_at: Captain::Behaviour::CHECK_IN_LOOKBACK.ago..)
           .where.not('EXISTS (SELECT 1 FROM messages later WHERE later.conversation_id = messages.conversation_id ' \
                      'AND later.message_type = 0 AND later.id > messages.id)')
           .select(:conversation_id)
  end

  def check_in(conversation)
    return false unless eligible?(conversation)

    content = Captain::Conversation::CheckInService.new(conversation: conversation, assistant: @assistant).perform
    message = post_locked(conversation) do
      conversation.messages.create!(
        content: content, content_type: 'text', message_type: :outgoing, account_id: conversation.account_id,
        inbox_id: conversation.inbox_id, sender: @assistant, preserve_waiting_since: true,
        additional_attributes: { 'agent_name' => @assistant.agent_name,
                                 Captain::Conversation::CheckInState::ATTRIBUTE_KEY => Captain::Conversation::CheckInState::CHECK_IN }
      )
    end
    emitted(conversation, Captain::Conversation::CheckInState::CHECK_IN) if message
  rescue ActiveRecord::RecordNotFound
    false
  end

  # Model calls happen outside the lock; inside it the conversation is reloaded and checked again,
  # so two overlapping runs send one check-in.
  def post_locked(conversation)
    conversation.with_lock do
      conversation.reload
      next unless eligible?(conversation)

      yield
    end
  end

  def eligible?(conversation)
    return false unless conversation.pending? && conversation.last_activity_at < cutoff_time

    state = Captain::Conversation::CheckInState.new(conversation: conversation, assistant: @assistant)
    return false unless state.assistant_spoke_last? && agent_may_reply?(conversation)
    # A form waits for the visitor: the business follow-up form, or any form the agent sent last.
    return false if state.last_public_message.content_type == 'form'
    return false if Captain::Leads::FollowupFormService.new(@assistant, conversation).pending?

    !state.checked_in_this_quiet_period?
  end

  def agent_may_reply?(conversation)
    ownership = Captain::Conversation::OwnershipService.new(conversation: conversation, assistant: @assistant)
    ownership.may_reply? && !ownership.waiting?
  end

  def emitted(conversation, kind)
    Captain::ConversationEvents.checked_in(conversation: conversation, assistant: @assistant, kind: kind, at: Time.current)
    true
  end
end

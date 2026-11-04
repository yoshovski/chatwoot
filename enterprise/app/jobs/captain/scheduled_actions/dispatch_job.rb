# Runs one scheduled action when it's due. The row is claimed under a lock, so a duplicate job (or the sweep) can't run
# it twice. Right before running, the cancel conditions are checked again in case an event was missed.
class Captain::ScheduledActions::DispatchJob < ApplicationJob
  queue_as :low

  RETRY_BACKOFF = [1.minute, 5.minutes].freeze

  def perform(action_id)
    action = Captain::ScheduledAction.find_by(id: action_id)
    return unless action&.pending?
    return self.class.set(wait_until: action.due_at).perform_later(action.id) if action.due_at > Time.current

    return unless claim(action)

    run(action)
  end

  private

  def claim(action)
    action.with_lock do
      next false unless action.pending? && action.due_at <= Time.current

      action.update!(status: :running)
    end
  end

  def run(action)
    reason = cancel_reason(action)
    return action.update!(status: :cancelled, cancelled_at: Time.current, cancel_reason: reason) if reason

    Captain::ScheduledActions.handler_for(action).new(action).perform
    action.update!(status: :done, executed_at: Time.current)
  rescue StandardError => e
    retry_or_fail(action, e)
  end

  def cancel_reason(action)
    return 'resolved' if action.conversation.resolved? && action.cancels_on?('resolved')

    reply_reason(action) || ('handoff' if action.cancels_on?('handoff') && !agent_may_reply?(action))
  end

  # A visitor message or a human's public reply after scheduling, in case its event was missed.
  def reply_reason(action)
    messages = action.conversation.messages.where(created_at: action.created_at..)
    return 'visitor_message' if action.cancels_on?('visitor_message') && messages.incoming.exists?

    'human_message' if action.cancels_on?('human_message') && messages.outgoing.exists?(private: false, sender_type: 'User')
  end

  def agent_may_reply?(action)
    ownership = Captain::Conversation::OwnershipService.new(conversation: action.conversation, assistant: action.assistant)
    ownership.may_reply? && !ownership.waiting?
  end

  def retry_or_fail(action, error)
    attempts = action.attempts + 1
    message = "#{error.class.name}: #{error.message}".truncate(1000)
    if attempts >= Captain::ScheduledAction::MAX_ATTEMPTS
      ChatwootExceptionTracker.new(error, account: action.account).capture_exception
      return action.update!(status: :failed, attempts: attempts, last_error: message)
    end

    due_at = Time.current + RETRY_BACKOFF.fetch(attempts - 1)
    action.update!(status: :pending, attempts: attempts, last_error: message, due_at: due_at)
    self.class.set(wait_until: due_at).perform_later(action.id)
  end
end

# Schedules and cancels Captain::ScheduledAction rows. A row runs once at due_at through DispatchJob; the sweep picks up
# rows whose job was lost. Each kind has a handler: Captain::ScheduledActions::<Kind>Handler.new(action).perform.
module Captain::ScheduledActions
  module_function

  # Returns the pending action. A second schedule with the same dedupe key returns the first one instead.
  # options: payload (Hash), cancel_on (reasons, default all), dedupe_key.
  def schedule!(conversation:, assistant:, kind:, at:, **options)
    action = Captain::ScheduledAction.create!(
      account_id: conversation.account_id, conversation: conversation, assistant: assistant, kind: kind, due_at: at,
      payload: options.fetch(:payload, {}), cancel_on: options.fetch(:cancel_on, Captain::ScheduledAction::CANCEL_REASONS),
      dedupe_key: options[:dedupe_key]
    )
    DispatchJob.set(wait_until: at).perform_later(action.id)
    action
  rescue ActiveRecord::RecordNotUnique
    Captain::ScheduledAction.pending.find_by!(conversation_id: conversation.id, kind: kind, dedupe_key: options[:dedupe_key])
  end

  # Cancels the conversation's pending actions that stop on this reason. Returns how many were cancelled.
  def cancel!(conversation:, reason:)
    now = Time.current
    Captain::ScheduledAction.where(conversation_id: conversation.id).cancellable_by(reason)
                            .update_all(status: 'cancelled', cancelled_at: now, cancel_reason: reason, updated_at: now) # rubocop:disable Rails/SkipsModelValidations
  end

  def handler_for(action) = "Captain::ScheduledActions::#{action.kind.camelize}Handler".constantize
end

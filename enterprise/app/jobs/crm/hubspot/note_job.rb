class Crm::Hubspot::NoteJob < MutexApplicationJob
  queue_as :medium
  retry_on Crm::Hubspot::Client::ApiError, wait: :polynomially_longer, attempts: 5
  retry_on LockAcquisitionError, wait: 5.seconds, attempts: 5
  discard_on Crm::Hubspot::Client::ReauthorizationRequired

  def perform(hook_id, conversation_id, resolved_at)
    hook = Integrations::Hook.find_by(id: hook_id, app_id: 'hubspot', status: :enabled)
    return unless hook

    conversation = hook.account.conversations.find_by(id: conversation_id)
    return unless conversation

    # Same lock as the contact sync: the note upserts the contact first.
    lock_key = format(::Redis::Alfred::HUBSPOT_CONTACT_MUTEX, hook_id: hook.id, contact_id: conversation.contact_id)
    with_lock(lock_key, Crm::Hubspot::SyncJob::LOCK_TIMEOUT) do
      Crm::Hubspot::ProcessorService.new(hook).handle_conversation_resolved(conversation, resolved_at)
    end
  end
end

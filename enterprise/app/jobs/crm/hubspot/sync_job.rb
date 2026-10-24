class Crm::Hubspot::SyncJob < MutexApplicationJob
  # Covers two HubSpot calls with a token refresh in between (15s timeout each).
  LOCK_TIMEOUT = 45.seconds

  queue_as :medium
  retry_on Crm::Hubspot::Client::ApiError, wait: :polynomially_longer, attempts: 5
  retry_on LockAcquisitionError, wait: 5.seconds, attempts: 5
  discard_on Crm::Hubspot::Client::ReauthorizationRequired

  def perform(hook_id, contact_id)
    hook = Integrations::Hook.find_by(id: hook_id, app_id: 'hubspot', status: :enabled)
    return unless hook

    contact = hook.account.contacts.find_by(id: contact_id)
    return unless contact

    # contact.created and contact.updated usually arrive together; the second job then finds the contact already synced.
    with_lock(format(::Redis::Alfred::HUBSPOT_CONTACT_MUTEX, hook_id: hook.id, contact_id: contact.id), LOCK_TIMEOUT) do
      Crm::Hubspot::ProcessorService.new(hook).handle_contact(contact)
    end
  end
end

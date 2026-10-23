class Crm::Hubspot::SyncJob < ApplicationJob
  queue_as :medium
  retry_on Crm::Hubspot::Client::ApiError, wait: :polynomially_longer, attempts: 5

  def perform(hook_id, contact_id)
    hook = Integrations::Hook.find_by(id: hook_id, app_id: 'hubspot', status: :enabled)
    return unless hook

    contact = hook.account.contacts.find_by(id: contact_id)
    return unless contact

    Crm::Hubspot::ProcessorService.new(hook).handle_contact(contact)
  end
end

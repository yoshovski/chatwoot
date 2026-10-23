require 'rails_helper'

RSpec.describe Crm::Hubspot::SyncJob do
  let(:account) { create(:account) }
  let(:hook) { create(:integrations_hook, :hubspot, account: account) }
  let(:contact) { create(:contact, account: account, email: 'jane@example.com') }
  let(:processor) { instance_double(Crm::Hubspot::ProcessorService) }

  before { allow(Crm::Hubspot::ProcessorService).to receive(:new).with(hook).and_return(processor) }

  it 'syncs the contact under a per-contact lock' do
    job = described_class.new
    allow(job).to receive(:with_lock).and_yield
    expect(processor).to receive(:handle_contact).with(contact)

    job.perform(hook.id, contact.id)

    expect(job).to have_received(:with_lock)
      .with(format(Redis::Alfred::HUBSPOT_CONTACT_MUTEX, hook_id: hook.id, contact_id: contact.id), described_class::LOCK_TIMEOUT)
  end

  it 'does nothing for a disabled hook' do
    hook.update!(status: :disabled)
    expect(processor).not_to receive(:handle_contact)

    described_class.perform_now(hook.id, contact.id)
  end

  it 'retries when the lock is held by another job' do
    Redis::LockManager.new.lock(format(Redis::Alfred::HUBSPOT_CONTACT_MUTEX, hook_id: hook.id, contact_id: contact.id), 10.seconds)

    expect { described_class.perform_now(hook.id, contact.id) }.to have_enqueued_job(described_class)
  ensure
    Redis::LockManager.new.unlock(format(Redis::Alfred::HUBSPOT_CONTACT_MUTEX, hook_id: hook.id, contact_id: contact.id))
  end

  it 'drops the job when HubSpot needs to be reauthorized' do
    allow(processor).to receive(:handle_contact).and_raise(Crm::Hubspot::Client::ReauthorizationRequired)

    expect { described_class.perform_now(hook.id, contact.id) }.not_to raise_error
  end
end

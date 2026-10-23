require 'rails_helper'

RSpec.describe Crm::Hubspot::NoteJob do
  let(:account) { create(:account) }
  let(:hook) { create(:integrations_hook, :hubspot, account: account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:resolved_at) { Time.zone.parse('2026-01-02 10:00:00 UTC') }
  let(:processor) { instance_double(Crm::Hubspot::ProcessorService) }

  before { allow(Crm::Hubspot::ProcessorService).to receive(:new).with(hook).and_return(processor) }

  it 'saves the transcript under the contact lock' do
    job = described_class.new
    allow(job).to receive(:with_lock).and_yield
    expect(processor).to receive(:handle_conversation_resolved).with(conversation, resolved_at)

    job.perform(hook.id, conversation.id, resolved_at)

    expect(job).to have_received(:with_lock)
      .with(format(Redis::Alfred::HUBSPOT_CONTACT_MUTEX, hook_id: hook.id, contact_id: conversation.contact_id),
            Crm::Hubspot::SyncJob::LOCK_TIMEOUT)
  end

  it 'does nothing for a disabled hook' do
    hook.update!(status: :disabled)
    expect(processor).not_to receive(:handle_conversation_resolved)

    described_class.perform_now(hook.id, conversation.id, resolved_at)
  end

  it 'retries HubSpot errors' do
    allow(processor).to receive(:handle_conversation_resolved).and_raise(Crm::Hubspot::Client::ApiError)

    expect { described_class.perform_now(hook.id, conversation.id, resolved_at) }.to have_enqueued_job(described_class)
  end
end

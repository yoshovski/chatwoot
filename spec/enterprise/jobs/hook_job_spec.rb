require 'rails_helper'

RSpec.describe HookJob do
  let(:account) { create(:account) }
  let(:hook) { create(:integrations_hook, :hubspot, account: account) }
  let(:contact) { create(:contact, account: account, email: 'jane@example.com') }

  it 'enqueues a HubSpot contact sync for contact.created and contact.updated' do
    expect do
      described_class.perform_now(hook, 'contact.created', contact: contact)
      described_class.perform_now(hook, 'contact.updated', contact: contact)
    end.to have_enqueued_job(Crm::Hubspot::SyncJob).with(hook.id, contact.id).exactly(:twice)
  end

  it 'enqueues a HubSpot transcript note with the resolve time for conversation.resolved' do
    conversation = create(:conversation, account: account, contact: contact)

    freeze_time do
      expect { described_class.perform_now(hook, 'conversation.resolved', conversation: conversation) }
        .to have_enqueued_job(Crm::Hubspot::NoteJob).with(hook.id, conversation.id, Time.current.change(usec: 0))
    end
  end
end

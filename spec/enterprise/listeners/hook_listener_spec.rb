require 'rails_helper'

describe HookListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let!(:hook) { create(:integrations_hook, :hubspot, account: account) }

  it 'enqueues the HubSpot hook for contact.created and contact.updated' do
    expect(HookJob).to receive(:perform_later).with(hook, 'contact.created', { contact: conversation.contact })
    expect(HookJob).to receive(:perform_later).with(hook, 'contact.updated', { contact: conversation.contact })

    listener.contact_created(Events::Base.new('contact.created', Time.zone.now, contact: conversation.contact))
    listener.contact_updated(Events::Base.new('contact.updated', Time.zone.now, contact: conversation.contact))
  end

  it 'enqueues the HubSpot hook for conversation.resolved' do
    conversation.update!(status: :resolved)
    expect(HookJob).to receive(:perform_later).with(hook, 'conversation.resolved', { conversation: conversation })

    listener.conversation_resolved(Events::Base.new('conversation.resolved', Time.zone.now, conversation: conversation))
  end
end

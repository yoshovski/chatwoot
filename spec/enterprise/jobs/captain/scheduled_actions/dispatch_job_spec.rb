require 'rails_helper'

RSpec.describe Captain::ScheduledActions::DispatchJob do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, status: :pending) }
  let(:action) do
    create(:captain_scheduled_action, conversation: conversation, assistant: assistant, created_at: 20.minutes.ago, due_at: 1.minute.ago)
  end
  let(:handler) { instance_double(Captain::ScheduledActions::FollowUpMessageHandler, perform: true) }

  before do
    create(:captain_inbox, captain_assistant: assistant, inbox: inbox)
    stub_const('Captain::ScheduledActions::FollowUpMessageHandler', Class.new { def initialize(_action); end })
    allow(Captain::ScheduledActions::FollowUpMessageHandler).to receive(:new).and_return(handler)
  end

  it 'runs the handler once when due and marks the action done' do
    described_class.perform_now(action.id)
    described_class.perform_now(action.id)

    expect(handler).to have_received(:perform).once
    expect(action.reload).to have_attributes(status: 'done', executed_at: be_present)
  end

  it 're-enqueues an action whose due_at moved later' do
    action.update!(due_at: 1.hour.from_now)

    expect { described_class.perform_now(action.id) }.to have_enqueued_job(described_class).with(action.id)
    expect(handler).not_to have_received(:perform)
    expect(action.reload.status).to eq('pending')
  end

  it 'does nothing for an action another job already claimed' do
    action.update!(status: :running)

    described_class.perform_now(action.id)

    expect(handler).not_to have_received(:perform)
  end

  it 'cancels instead of running when the visitor wrote after scheduling' do
    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming)

    described_class.perform_now(action.id)

    expect(handler).not_to have_received(:perform)
    expect(action.reload).to have_attributes(status: 'cancelled', cancel_reason: 'visitor_message')
  end

  it 'cancels instead of running when the conversation was resolved' do
    conversation.update!(status: :resolved)

    described_class.perform_now(action.id)

    expect(action.reload).to have_attributes(status: 'cancelled', cancel_reason: 'resolved')
  end

  it 'cancels instead of running when a human took the conversation' do
    conversation.update!(status: :open)

    described_class.perform_now(action.id)

    expect(action.reload).to have_attributes(status: 'cancelled', cancel_reason: 'handoff')
  end

  it 'retries with backoff, then marks the action failed' do
    allow(handler).to receive(:perform).and_raise(StandardError, 'smtp down')

    described_class.perform_now(action.id)
    expect(action.reload).to have_attributes(status: 'pending', attempts: 1, last_error: 'StandardError: smtp down')

    action.update!(due_at: 1.second.ago)
    described_class.perform_now(action.id)
    action.update!(due_at: 1.second.ago)
    described_class.perform_now(action.id)

    expect(action.reload).to have_attributes(status: 'failed', attempts: 3)
  end
end

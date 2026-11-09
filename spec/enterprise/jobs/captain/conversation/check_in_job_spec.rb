# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Captain::Conversation::CheckInJob, type: :job do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:conversation) { create(:conversation, inbox: inbox, account: account, status: :pending) }
  let(:runner) { instance_double(Captain::Conversation::CheckInRunner) }

  before do
    account.enable_features!('captain_integration_v2')
    allow(Captain::Conversation::CheckInRunner).to receive(:new).with(inbox: inbox, assistant: assistant).and_return(runner)
  end

  it 'delegates to CheckInRunner with proactive: true' do
    expect(runner).to receive(:check_in).with(conversation, proactive: true).and_return(true)

    described_class.perform_now(conversation.id, assistant.id)
  end

  it 'does nothing if captain_integration_v2 is disabled' do
    account.disable_features!('captain_integration_v2')
    expect(runner).not_to receive(:check_in)

    described_class.perform_now(conversation.id, assistant.id)
  end

  it 'does nothing if conversation is missing' do
    expect(runner).not_to receive(:check_in)

    described_class.perform_now(-1, assistant.id)
  end
end

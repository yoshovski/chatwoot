require 'rails_helper'

RSpec.describe Captain::Conversation::HandoffPolicy do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:conversation) { create(:conversation, inbox: inbox, account: account) }
  let(:policy) { described_class.new(assistant: assistant, conversation: conversation) }

  before { create(:inbox_member, inbox: inbox, user: agent) }

  def online!
    allow(OnlineStatusTracker).to receive(:get_available_users).with(account.id).and_return({ agent.id.to_s => 'online' })
  end

  it 'transfers by default, online or not' do
    expect(policy.keep?).to be(false)
    expect(policy.team_online?).to be(false)
  end

  it 'keeps the conversation when the rule for the current state says so' do
    assistant.update!(config: { 'handoff_when_online' => 'transfer', 'handoff_when_offline' => 'keep' })

    expect(policy.keep?).to be(true)
    expect(policy.prompt_instruction).to include("Don't hand off", I18n.t('conversations.captain.no_handoff'))
  end

  it 'counts the team offline outside working hours even with someone online' do
    online!
    allow(inbox).to receive(:out_of_office?).and_return(true)
    allow(conversation).to receive(:inbox).and_return(inbox)

    expect(policy.team_online?).to be(false)
  end

  it 'uses the offline handoff message only while the team is offline' do
    assistant.update!(config: { 'handoff_message' => 'Connecting you now.', 'offline_handoff_message' => 'We reply tomorrow.' })

    expect(policy.handoff_message).to eq('We reply tomorrow.')
    expect(policy.prompt_instruction).to include('We reply tomorrow.')
    online!
    expect(described_class.new(assistant: assistant, conversation: conversation).handoff_message).to eq('Connecting you now.')
  end
end

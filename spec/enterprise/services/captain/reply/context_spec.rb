require 'rails_helper'

RSpec.describe Captain::Reply::Context do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:state) { { first_ai_reply: true, lead_followup_form_requested: true, captain_action_confirmation: { 'nonce' => 'n1' } } }
  let(:run_result) { instance_double(Agents::RunResult, context: { state: state }) }

  def channel(channel)
    conversation = create(:conversation, account: account, inbox: create(:inbox, account: account, channel: channel))
    described_class.build(assistant: assistant, conversation: conversation, run_result: run_result).channel
  end

  it 'reads the run state' do
    context = described_class.build(assistant: assistant, run_result: run_result, suppress_suggestions: true)

    expect(context).to have_attributes(first_ai_reply: true, followup_form_requested: true, suppress_suggestions: true,
                                       action_confirmation: { 'nonce' => 'n1' }, channel: :widget)
  end

  it 'names the channel' do
    expect(channel(create(:channel_widget, account: account))).to eq(:widget)
    expect(channel(create(:channel_email, account: account))).to eq(:email)
    expect(channel(create(:channel_sms, account: account))).to eq(:messaging)
  end
end

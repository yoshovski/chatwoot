require 'rails_helper'

RSpec.describe Captain::Conversation::CheckInService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:service) { described_class.new(conversation: conversation, assistant: assistant) }
  let(:chat) { instance_double(RubyLLM::Chat) }

  before do
    create(:message, conversation: conversation, account: account, inbox: inbox, content: 'Can I export my invoices?')
    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing, sender: assistant,
                     content: 'Yes, from Billing > Invoices. Do you need them as CSV or PDF?')
    allow(Captain::Assistant::TieredLlmClient).to receive(:chat).and_return(chat)
    allow(chat).to receive_messages(with_schema: chat, with_params: chat, with_instructions: chat)
  end

  def reply(content) = instance_double(RubyLLM::Message, content: content)

  it 'writes the check-in from the recent messages without a greeting or new information' do
    allow(Captain::Assistant::TieredLlmClient).to receive(:generate).and_return(reply({ 'text' => 'Would CSV or PDF suit you better?' }))

    expect(service.perform).to eq('Would CSV or PDF suit you better?')
    expect(described_class::INSTRUCTIONS).to include('No greeting, no new information')
    expect(Captain::Assistant::TieredLlmClient).to have_received(:generate) do |stage, _assistant, _chat, input|
      expect(stage).to eq('check_in')
      expect(JSON.parse(input)['messages'].pluck('role')).to eq(%w[user assistant])
    end
    expect(Captain::Assistant::TieredLlmClient).to have_received(:chat)
      .with(account_id: account.id, model: 'knowledge-answer', timeout: Captain::Behaviour::CHECK_IN_TIMEOUT_SECONDS)
  end

  it 'falls back to the fixed check-in when the model fails' do
    allow(Captain::Assistant::TieredLlmClient).to receive(:generate).and_raise(Faraday::TimeoutError)

    expect(service.perform).to eq('Is there anything else I can help you with?')
  end

  it 'falls back when the check-in is longer than the cap' do
    allow(Captain::Assistant::TieredLlmClient).to receive(:generate).and_return(reply({ 'text' => 'a' * 201 }))

    expect(service.perform).to eq('Is there anything else I can help you with?')
  end

  it 'falls back on empty or invalid output' do
    allow(Captain::Assistant::TieredLlmClient).to receive(:generate).and_return(reply({ 'text' => ' ' }), reply('not json'))

    expect([service.perform, service.perform]).to all(eq('Is there anything else I can help you with?'))
  end

  it 'writes a scheduled follow-up from its brief' do
    allow(Captain::Assistant::TieredLlmClient).to receive(:generate).and_return(reply({ 'text' => 'Did the plan comparison help?' }))

    result = described_class.new(conversation: conversation, assistant: assistant, brief: 'Ask if the plan comparison helped').perform

    expect(result).to eq('Did the plan comparison help?')
    expect(chat).to have_received(:with_instructions).with(include('that does this: Ask if the plan comparison helped'))
  end
end

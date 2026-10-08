require 'rails_helper'

RSpec.describe Captain::Conversation::HandoffNoteService do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:service) { described_class.new(conversation: conversation, assistant: assistant) }

  before do
    create(:installation_config, name: 'CAPTAIN_OPEN_AI_API_KEY', value: 'test-key')
    Llm::Config.reset!
    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming,
                     content: 'I need 10 batteries for the T100 by Friday')
    stub_request(:post, %r{/chat/completions})
      .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                 body: { choices: [{ message: { role: 'assistant', content: "Wants: 10 T100 batteries\nNext: send a quote" } }] }.to_json)
  end

  after { Llm::Config.reset! }

  it 'summarizes the conversation with the LLM' do
    expect(service.generate_note_content).to eq("#{described_class::NOTE_HEADER}\nWants: 10 T100 batteries\nNext: send a quote")
  end

  it 'skips the LLM when the account has no Captain responses left' do
    allow(account).to receive(:usage_limits).and_return(captain: { responses: { current_available: 0 } })
    allow(conversation).to receive(:account).and_return(account)

    expect(service.generate_note_content).to eq("#{described_class::NOTE_HEADER}\n#{described_class::FALLBACK_NOTE}")
    expect(WebMock).not_to have_requested(:post, %r{/chat/completions})
  end

  it 'falls back to the thread hint when the LLM call fails' do
    stub_request(:post, %r{/chat/completions}).to_return(status: 500, body: '{}')

    expect(service.generate_note_content).to eq("#{described_class::NOTE_HEADER}\n#{described_class::FALLBACK_NOTE}")
  end
end

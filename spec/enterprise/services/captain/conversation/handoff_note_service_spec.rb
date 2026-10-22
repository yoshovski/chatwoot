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

  it 'drops lines the model left empty' do
    note = "Wants: help with streaming\nDetails: None\nNext: troubleshoot"
    stub_request(:post, %r{/chat/completions})
      .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                 body: { choices: [{ message: { role: 'assistant', content: note } }] }.to_json)

    expect(service.generate_note_content).to eq("#{described_class::NOTE_HEADER}\nWants: help with streaming\nNext: troubleshoot")
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

  it 'formats long narrative handoff reasons into clean bullet points' do
    long_reason = 'Customer asks whether generator will keep up with their DJI T50 after another generator failed. ' \
                  'Catalog confirms D12000iE is compatible with T50 and rated 12,000W; colleague should verify against their setup.'
    service_with_reason = described_class.new(conversation: conversation, assistant: assistant, reason: long_reason)

    expect(service_with_reason.generate_note_content).to eq(
      "#{described_class::NOTE_HEADER}\n" \
      "- Customer asks whether generator will keep up with their DJI T50 after another generator failed.\n" \
      "- Catalog confirms D12000iE is compatible with T50 and rated 12,000W\n" \
      '- colleague should verify against their setup.'
    )
  end
end

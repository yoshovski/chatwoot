require 'rails_helper'

# The router's welcome on the first widget reply is posted before the answer is generated (CWAI-137 follow-up).
RSpec.describe Captain::Assistant::AgentRunnerService do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:inbox) { create(:inbox, account: account, channel: create(:channel_widget, account: account)) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, status: :pending) }
  let!(:visitor_message) { create(:message, conversation: conversation, message_type: :incoming, content: 'How do I clear my cache?') }
  let(:chat) { instance_double(RubyLLM::Chat) }
  let(:lookup) { instance_double(Captain::Tools::FaqLookupTool) }
  let(:instructions) { [] }
  let(:route) { { 'intent' => 'faq_kb', 'queries' => ['clear browser cache'], 'welcome' => 'Hi, welcome to Acme!' } }
  let(:answer) { { 'response_parts' => [{ 'text' => 'Open the browser menu and delete the cached files.', 'citation_indexes' => [] }] } }
  let(:messages_before_answer) { [] }

  def generate(history: [{ role: 'user', content: 'How do I clear my cache?' }])
    with_modified_env CAPTAIN_INTENT_ROUTING_MODE: 'on' do
      described_class.new(assistant: assistant, conversation: conversation,
                          run_options: described_class::RunOptions.new(responding_to_message_id: visitor_message.id))
                     .generate_response(message_history: history)
    end
  end

  def greetings = conversation.messages.outgoing.select { |message| message.additional_attributes['captain_segment_kinds'] == ['greeting'] }

  before do
    create(:captain_inbox, captain_assistant: assistant, inbox: inbox)
    allow(Captain::Assistant::TieredLlmClient).to receive(:chat).and_return(chat)
    allow(chat).to receive_messages(with_params: chat, with_schema: chat, add_message: chat)
    allow(chat).to receive(:with_instructions) { |text, **| instructions << text and chat }
    allow(Captain::Assistant::TieredLlmClient).to receive(:generate) do |stage, *|
      messages_before_answer.concat(conversation.messages.outgoing.reload.to_a) unless stage == 'classify'
      content = stage == 'classify' ? route : answer
      instance_double(RubyLLM::Message, content: content, input_tokens: 1, output_tokens: 1, cached_tokens: 0)
    end
    allow(Captain::Tools::FaqLookupTool).to receive(:new).and_return(lookup)
    allow(lookup).to receive(:perform_queries).and_return('How to clear your browser cache: open the browser menu…')
    allow(Captain::ResponseSchema).to receive(:for).and_call_original
  end

  it 'posts the welcome as its own greeting message before the answer is generated' do
    generate

    expect(messages_before_answer.map(&:content)).to eq(['Hi, welcome to Acme!'])
    expect(greetings.size).to eq(1)
    expect(greetings.first.additional_attributes).to include('captain_reply_id', 'captain_reveal_offset_ms')
    expect(instructions.find { |text| text.include?('Configured business and routing policy') }).to include('"welcome"')
  end

  it 'builds the main reply knowing the visitor was welcomed' do
    result = generate

    expect(Captain::ResponseSchema).to have_received(:for).with(hash_including(welcome: false))
    expect(instructions.join).to include('already welcomed in a separate message')
    expect(instructions.join).not_to include('in `welcome`')
    expect(result['response_parts'].first['text']).to eq('Open the browser menu and delete the cached files.')
  end

  it 'posts at most one welcome per conversation' do
    create(:message, conversation: conversation, message_type: :outgoing, sender: assistant, content: 'Hello!',
                     additional_attributes: { 'captain_segment_kinds' => ['greeting'] })

    generate

    expect(greetings.size).to eq(1)
    expect(Captain::ResponseSchema).to have_received(:for).with(hash_including(welcome: false))
  end

  it 'leaves the welcome to the newer visitor message when one arrived' do
    create(:message, conversation: conversation, message_type: :incoming, content: 'And on Safari?')

    generate

    expect(greetings).to be_empty
    expect(Captain::ResponseSchema).to have_received(:for).with(hash_including(welcome: true))
  end

  it 'posts nothing when a human took over' do
    conversation.update!(status: :open, assignee: create(:user, account: account))

    generate

    expect(greetings).to be_empty
  end

  context 'when the router returns no welcome' do
    let(:route) { { 'intent' => 'faq_kb', 'queries' => ['clear browser cache'] } }

    it 'falls back to the welcome of the main reply' do
      generate

      expect(greetings).to be_empty
      expect(Captain::ResponseSchema).to have_received(:for).with(hash_including(welcome: true))
    end
  end

  context 'when the router skips the classifier' do
    it 'falls back to the welcome of the main reply for a plain hello' do
      generate(history: [{ role: 'user', content: 'hi' }])

      expect(greetings).to be_empty
      expect(Captain::ResponseSchema).to have_received(:for).with(hash_including(welcome: true))
    end
  end

  context 'when it is not the first reply' do
    it 'asks the router for no welcome' do
      generate(history: [{ role: 'user', content: 'Hello' }, { role: 'assistant', content: 'Hi! How can I help?' },
                         { role: 'user', content: 'How do I clear my cache?' }])

      expect(greetings).to be_empty
      expect(instructions.find { |text| text.include?('Configured business and routing policy') }).not_to include('"welcome"')
    end
  end

  context 'with an email inbox' do
    let(:inbox) { create(:inbox, account: account, channel: create(:channel_email, account: account)) }

    it 'keeps the single message and asks the router for no welcome' do
      generate

      expect(greetings).to be_empty
      expect(instructions.find { |text| text.include?('Configured business and routing policy') }).not_to include('"welcome"')
      expect(Captain::ResponseSchema).to have_received(:for).with(hash_including(welcome: true))
    end
  end
end

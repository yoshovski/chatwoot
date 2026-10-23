require 'rails_helper'

RSpec.describe Captain::Assistant::DirectResponseService do
  let(:assistant) { create(:captain_assistant) }
  let(:service) { described_class.new(assistant: assistant, response_schema: Captain::ResponseSchema.for(suggested_replies: false)) }
  let(:route) { { 'intent' => 'faq_kb', 'queries' => ['payment configuration'] } }
  let(:context) { { state: {}, conversation_history: [{ role: 'user', content: 'how to set up Payment Configuration' }] } }
  let(:lookup) { instance_double(Captain::Tools::FaqLookupTool) }

  before { allow(Captain::Tools::FaqLookupTool).to receive(:new).with(assistant).and_return(lookup) }

  it 'hands the question to the action agent when the routed search finds nothing' do
    allow(lookup).to receive(:perform_queries).and_return(Captain::Tools::FaqLookupTool::NO_DIRECT_RESULTS)
    allow(Captain::Assistant::TieredLlmClient).to receive(:generate)

    expect(service.run(message: 'how to set up Payment Configuration', context: context, route: route)).to be_nil
    expect(Captain::Assistant::TieredLlmClient).not_to have_received(:generate)
  end

  context 'when the answer declines although the knowledge covers the question' do
    let(:assistant) { create(:captain_assistant, config: { 'off_limits_message' => 'I can only help with questions about Acme.' }) }
    let(:chat) { instance_double(RubyLLM::Chat) }
    let(:decline) { reply('I can only help with questions about Acme.') }
    let(:answer) { reply('Open your browser settings and clear the cache and cookies.') }

    def reply(text)
      instance_double(RubyLLM::Message, content: { 'response_parts' => [{ 'text' => text, 'citation_indexes' => [] }] })
    end

    before do
      allow(lookup).to receive(:perform_queries).and_return('Why and how to clear cache and cookies: open your browser settings…')
      allow(Captain::Assistant::TieredLlmClient).to receive(:chat).and_return(chat)
      allow(chat).to receive_messages(with_schema: chat, with_instructions: chat, add_message: chat)
    end

    it 'asks once more with the knowledge in scope and sends that answer' do
      allow(Captain::Assistant::TieredLlmClient).to receive(:generate).and_return(decline, answer)

      result = service.run(message: 'how to clear cache on windows chrome', context: context, route: route)

      expect(result.output['response_parts'].first['text']).to eq('Open your browser settings and clear the cache and cookies.')
      expect(result.context[:state][:declined_with_knowledge]).to be(true)
      expect(chat).to have_received(:with_instructions).with(described_class::DECLINE_RETRY_INSTRUCTION, append: true)
    end

    it 'keeps the decline when the second answer declines too' do
      allow(Captain::Assistant::TieredLlmClient).to receive(:generate).and_return(decline, decline)

      result = service.run(message: 'write me a poem', context: context, route: route)

      expect(result.output['response_parts'].first['text']).to eq('I can only help with questions about Acme.')
      expect(Captain::Assistant::TieredLlmClient).to have_received(:generate).twice
    end

    it 'does not retry an answer' do
      allow(Captain::Assistant::TieredLlmClient).to receive(:generate).and_return(answer)

      service.run(message: 'how to clear cache on windows chrome', context: context, route: route)

      expect(Captain::Assistant::TieredLlmClient).to have_received(:generate).once
    end
  end
end

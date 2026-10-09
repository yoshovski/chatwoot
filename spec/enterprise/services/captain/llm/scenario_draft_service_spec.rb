require 'rails_helper'

RSpec.describe Captain::Llm::ScenarioDraftService do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:user_prompt) { 'Help customers return damaged items and check order status' }
  let(:service) { described_class.new(assistant: assistant, user_prompt: user_prompt) }
  let(:mock_chat) { instance_double(RubyLLM::Chat) }

  let(:llm_response_content) do
    {
      title: 'Returns & warranty claim',
      description: 'Use when the customer wants to return an item or report a damaged product.',
      instruction: "1. Ask for details\n2. Verify with [@Search knowledge](tool://faq_lookup)\n3. Check with [@Invalid Tool](tool://unknown_tool)",
      notes: ['A tool that issues return labels would help.']
    }.to_json
  end

  let(:mock_response) do
    instance_double(RubyLLM::Message, content: llm_response_content)
  end

  before do
    create(:installation_config, name: 'CAPTAIN_OPEN_AI_API_KEY', value: 'test-key')
    allow(RubyLLM).to receive(:chat).and_return(mock_chat)
    allow(mock_chat).to receive(:with_temperature).and_return(mock_chat)
    allow(mock_chat).to receive(:with_params).and_return(mock_chat)
    allow(mock_chat).to receive(:with_instructions).and_return(mock_chat)
    allow(mock_chat).to receive(:ask).and_return(mock_response)
  end

  describe '#perform' do
    context 'when LLM returns valid scenario JSON' do
      it 'drops links for unknown tools while keeping their text, and correctly populates tools' do
        result = service.perform

        expect(result[:title]).to eq('Returns & warranty claim')
        expect(result[:description]).to eq('Use when the customer wants to return an item or report a damaged product.')
        # faq_lookup is available, so link is preserved
        expect(result[:instruction]).to include('[@Search knowledge](tool://faq_lookup)')
        # unknown_tool is dropped, keeping its text
        expect(result[:instruction]).to include('Check with @Invalid Tool')
        expect(result[:instruction]).not_to include('tool://unknown_tool')
        # tools only contains available tool
        expect(result[:tools]).to eq(['faq_lookup'])
        expect(result[:notes]).to eq(['A tool that issues return labels would help.'])
      end

      it 'truncates title to 60 characters and description to 500 characters' do
        long_content = {
          title: 'A' * 80,
          description: "Use when #{'B' * 600}",
          instruction: 'Step 1'
        }.to_json
        allow(mock_chat).to receive(:ask).and_return(instance_double(RubyLLM::Message, content: long_content))

        result = service.perform

        expect(result[:title].length).to eq(60)
        expect(result[:description].length).to eq(500)
      end
    end

    context 'when LLM returns invalid JSON or empty output' do
      it 'returns nil for unparseable output' do
        allow(mock_chat).to receive(:ask).and_return(instance_double(RubyLLM::Message, content: 'Not valid json'))

        expect(service.perform).to be_nil
      end

      it 'returns nil for blank output' do
        allow(mock_chat).to receive(:ask).and_return(instance_double(RubyLLM::Message, content: ''))

        expect(service.perform).to be_nil
      end
    end
  end
end

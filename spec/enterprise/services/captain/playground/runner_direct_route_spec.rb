require 'rails_helper'

RSpec.describe Captain::Playground::Runner do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:chat) { instance_double(RubyLLM::Chat) }
  let(:lookup) { instance_double(Captain::Tools::FaqLookupTool) }
  let(:instructions) { [] }
  let(:guideline) { 'Mention the Acme status page when the dashboard is slow.' }

  before do
    allow(Captain::Assistant::TieredLlmClient).to receive(:chat).and_return(chat)
    allow(chat).to receive_messages(with_params: chat, with_schema: chat, add_message: chat)
    allow(chat).to receive(:with_instructions) { |text, **| instructions << text and chat }
    allow(Captain::Assistant::TieredLlmClient).to receive(:generate) do |stage, *|
      content = if stage == 'classify'
                  { 'intent' => 'faq_kb', 'queries' => ['clear browser cache'] }
                else
                  { 'response_parts' => [{ 'text' => 'Open the browser menu and delete the cached files.', 'citation_indexes' => [] }] }
                end
      instance_double(RubyLLM::Message, content: content, input_tokens: 1, output_tokens: 1, cached_tokens: 0)
    end
    allow(Captain::Tools::FaqLookupTool).to receive(:new).and_return(lookup)
    allow(lookup).to receive(:perform_queries).and_return('How to clear your browser cache: open the browser menu…')
    allow(Agents::Runner).to receive(:with_agents)
  end

  it 'answers a knowledge question through the direct route with the unsaved settings' do
    result = with_modified_env CAPTAIN_INTENT_ROUTING_MODE: 'on' do
      described_class.new(
        assistant: assistant, configuration_params: { response_guidelines: [guideline] },
        message_history: [{ role: 'user', content: 'How do I clear my cache?' }]
      ).generate_response
    end

    expect(result[:messages].first[:content]).to eq('Open the browser menu and delete the cached files.')
    expect(Captain::Assistant::TieredLlmClient).to have_received(:generate).with('knowledge_answer', assistant, chat, 'How do I clear my cache?')
    expect(lookup).to have_received(:perform_queries).with(anything, queries: ['clear browser cache'])
    expect(instructions.find { |text| text.include?('Response guideline:') }).to include("Response guideline: #{guideline}")
    expect(instructions.find { |text| text.include?('Configured business and routing policy') }).to include(guideline)
    expect(Agents::Runner).not_to have_received(:with_agents)
  end
end

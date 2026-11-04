require 'rails_helper'

RSpec.describe Captain::Assistant::IntentRouter do
  subject(:router) { described_class.new(assistant: assistant) }

  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account, config: { 'greeting_mode' => 'off' }) }
  let(:context) { { conversation_history: [], state: {} } }

  describe 'greetings' do
    it 'routes a plain hello to the model without canned text, whatever an older setting stored' do
      route = router.classify(message: 'Thank you!', context: context)

      expect(route).to eq('intent' => 'smalltalk', 'queries' => [], 'reason' => 'greeting')
    end

    it 'lets the model greet in the agent voice when the greeting is on' do
      assistant.update!(config: { 'greeting_mode' => 'ai' })

      route = router.classify(message: 'Hi!', context: context)

      expect(route).to include('intent' => 'smalltalk', 'reason' => 'greeting')
      expect(route).not_to have_key('canned_response')
    end
  end

  describe 'early welcome' do
    let(:chat) { instance_double(RubyLLM::Chat) }
    let(:instructions) { [] }
    let(:classified) { { 'intent' => 'faq_kb', 'queries' => ['free trial'], 'welcome' => '  Hi, welcome to Acme!  ' } }

    before do
      allow(Captain::Assistant::TieredLlmClient).to receive(:chat).and_return(chat)
      allow(chat).to receive(:with_params).and_return(chat)
      allow(chat).to receive(:with_instructions) { |text| instructions << text and chat }
      allow(Captain::Assistant::TieredLlmClient).to receive(:generate)
        .and_return(instance_double(RubyLLM::Message, content: classified))
    end

    it 'asks for the welcome and returns it on the first widget reply' do
      route = described_class.new(assistant: assistant, welcome: true).classify(message: 'Is there a free trial?', context: context)

      expect(route).to include('intent' => 'faq_kb', 'welcome' => 'Hi, welcome to Acme!')
      expect(instructions.first).to include('Also return "welcome"')
    end

    it 'neither asks for nor returns a welcome otherwise' do
      route = router.classify(message: 'Is there a free trial?', context: context)

      expect(route).not_to have_key('welcome')
      expect(instructions.first).not_to include('"welcome"')
    end

    it 'drops a welcome that is not one short line' do
      classified['welcome'] = "Hi!\nWelcome to Acme."

      route = described_class.new(assistant: assistant, welcome: true).classify(message: 'Is there a free trial?', context: context)

      expect(route).to include('intent' => 'faq_kb')
      expect(route).not_to have_key('welcome')
    end
  end
end

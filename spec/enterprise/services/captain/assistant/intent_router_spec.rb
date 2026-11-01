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
end

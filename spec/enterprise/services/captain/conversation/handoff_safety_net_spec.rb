# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Captain::Conversation::HandoffSafetyNet do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }

  describe '#triggered?' do
    it 'returns true for a dead-end answer without an alternative' do
      service = described_class.new(
        assistant: assistant,
        customer_message: 'Can you tell me about this product?',
        answer: 'I cannot find that product in our catalog.'
      )

      expect(service.triggered?).to be true
    end

    it 'returns false for a dead-end answer followed by an alternative' do
      service = described_class.new(
        assistant: assistant,
        customer_message: 'Do you have the model DB200?',
        answer: 'I cannot find that product in our catalog, but we do have the newer DB300 model in stock.'
      )

      expect(service.triggered?).to be false
    end

    it 'returns true when the customer message matches a configured keyword' do
      service = described_class.new(
        assistant: assistant,
        customer_message: 'My order arrived damaged yesterday.',
        answer: 'Here is information on our products.'
      )

      expect(service.triggered?).to be true
    end

    it 'returns false when neither dead-end nor customer keywords match' do
      service = described_class.new(
        assistant: assistant,
        customer_message: 'What are your store opening hours?',
        answer: 'We are open Monday to Friday from 9am to 5pm.'
      )

      expect(service.triggered?).to be false
    end
  end
end

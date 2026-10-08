# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Captain::Conversation::ReplyLabels do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }

  describe '#labels' do
    it 'returns matched labels in predefined order' do
      service = described_class.new(
        assistant: assistant,
        customer_message: 'Can I get a bulk quote for my order? Also does it fit model X?',
        answer: 'Here are the specifications.'
      )

      expect(service.labels).to eq(%w[quote-request order-issue compatibility])
    end

    it 'includes needs-human first when handed off' do
      service = described_class.new(
        assistant: assistant,
        customer_message: 'Can you give me a discount on this?',
        answer: 'Let me transfer you to a colleague.',
        handed_off: true
      )

      expect(service.labels).to eq(%w[needs-human quote-request])
    end

    it 'matches out-of-stock on answer and product-inquiry on products_shown' do
      service = described_class.new(
        assistant: assistant,
        customer_message: 'How much does it cost?',
        answer: 'Unfortunately this item is currently sold out.',
        products_shown: true
      )

      expect(service.labels).to eq(%w[out-of-stock product-inquiry])
    end

    it 'enforces maximum of 3 labels and applies configured regulation keywords' do
      assistant.update!(config: assistant.config.merge('reply_label_keywords' => { 'regulation' => ['ce marked'] }))
      service = described_class.new(
        assistant: assistant,
        customer_message: 'I need a bulk discount quote for my order number 123. Does it fit model Y and is it CE marked? What is the warranty?',
        answer: 'It is currently out of stock.',
        handed_off: true
      )

      # Candidates in order: needs-human, quote-request, order-issue, compatibility, out-of-stock, regulation, policy
      # Cut-off at 3 labels:
      expect(service.labels).to eq(%w[needs-human quote-request order-issue])
      expect(service.labels.size).to eq(3)
    end
  end
end

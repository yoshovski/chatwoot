require 'rails_helper'

RSpec.describe Captain::Conversation::HandoffDetector do
  def response(text, **attributes)
    { 'response_parts' => [{ 'text' => text, 'citation_indexes' => [] }], 'response' => text, **attributes.stringify_keys }
  end

  describe '.declared?' do
    it 'is true when the model sets handoff_requested' do
      expect(described_class.declared?(response('Sure.', handoff_requested: true))).to be(true)
    end

    [
      "I can't issue refunds. A billing colleague will reply to you here.",
      'One of our team members will continue in this chat.',
      'Someone from our billing team will be with you shortly. Thanks for waiting.',
      "A support agent'll take over from here."
    ].each do |text|
      it "is true for a promise without the flag: #{text}" do
        expect(described_class.declared?(response(text, handoff_requested: false))).to be(true)
      end
    end

    [
      'Our team can follow up by email with a quote.',
      'A colleague will reply by email within a day.',
      'Would you like a colleague to continue in this chat?',
      'If you want, a colleague will continue in this chat.',
      'Our specialists will continue to improve the churn model.',
      'Yearly plans can be refunded within 30 days of payment.'
    ].each do |text|
      it "is false without a live-chat promise: #{text}" do
        expect(described_class.declared?(response(text))).to be(false)
      end
    end

    it 'reads only replies with response parts' do
      expect(described_class.declared?({ 'response' => 'A colleague will reply to you here.' })).to be(false)
    end
  end
end

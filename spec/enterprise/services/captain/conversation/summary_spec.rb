require 'rails_helper'

RSpec.describe Captain::Conversation::Summary do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, additional_attributes: { 'browser' => 'Firefox' }).reload }
  let(:summary) { described_class.new(conversation) }
  let(:stored) { conversation.reload.additional_attributes['captain_summary'] }

  describe '.parse' do
    it 'reads the handoff prompt lines and ignores the rest' do
      text = "🔔 **Needs your reply**\nWants: Club price for 40 boots\nDetails: sizes 38-46\nNext: Send a quote\nThanks"

      expect(described_class.parse(text)).to eq('wants' => 'Club price for 40 boots', 'details' => 'sizes 38-46', 'next_step' => 'Send a quote')
    end
  end

  describe '#record_handoff!' do
    it 'stores the generated summary next to the other attributes' do
      summary.record_handoff!(note_content: "🔔 **Needs your reply**\nWants: A refund\nNext: Check the order", reason: nil)

      expect(conversation.reload.additional_attributes['browser']).to eq('Firefox')
      expect(stored).to include('status' => 'handed_off', 'wants' => 'A refund', 'next_step' => 'Check the order', 'reason' => nil)
    end

    it "keeps the agent's reason and writes the full summary in the background" do
      expect do
        summary.record_handoff!(note_content: "🔔 **Needs your reply**\nCustomer asks for a bulk discount",
                                reason: 'Customer asks for a bulk discount')
      end.to have_enqueued_job(Captain::Conversation::SummaryJob).with(conversation, 'handed_off')

      expect(stored).to include('status' => 'handed_off', 'reason' => 'Customer asks for a bulk discount')
    end
  end

  describe '#record_action!' do
    it 'appends each action outcome' do
      summary.record_action!(title: 'Cancel order', outcome: :succeeded)
      summary.record_action!(title: 'Change address', outcome: :cancelled)

      expect(stored['status']).to eq('action')
      expect(stored['actions'].pluck('title', 'outcome')).to eq([['Cancel order', 'succeeded'], ['Change address', 'cancelled']])
    end
  end
end

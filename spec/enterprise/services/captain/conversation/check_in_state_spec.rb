require 'rails_helper'

RSpec.describe Captain::Conversation::CheckInState do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:assistant) do
    create(:captain_assistant, account: account, config: {
             'leads_enabled' => true, 'lead_types' => [{ 'name' => 'Demo', 'rule' => 'Wants to see the product' }]
           })
  end
  let(:conversation) { create(:conversation, account: account, inbox: inbox, status: :pending) }
  let(:state) { described_class.new(conversation: conversation, assistant: assistant) }

  before do
    create(:captain_inbox, inbox: inbox, captain_assistant: assistant)
    create(:message, conversation: conversation, account: account, inbox: inbox, content: 'Could Acme work for our agency?')
  end

  def agent_message(**attrs)
    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing, sender: assistant,
                     content: 'How many clients do you manage?', **attrs)
  end

  describe '#lead_guard?' do
    before { agent_message(additional_attributes: { 'business_lead_question' => true }) }

    it 'applies to a prospect the agent asked a qualification question' do
      expect(state.lead_guard?).to be(true)
    end

    it 'needs business leads to be on' do
      assistant.update!(config: assistant.config.merge('leads_enabled' => false))

      expect(state.lead_guard?).to be(false)
    end

    it 'needs a qualification question' do
      conversation.messages.where(sender: assistant).destroy_all
      agent_message

      expect(state.lead_guard?).to be(false)
    end

    it 'ends once a lead offer was sent' do
      agent_message(additional_attributes: { 'captain_initiated' => 'lead_offer' })

      expect(state.lead_guard?).to be(false)
      expect(state.lead_offer_sent?).to be(true)
    end

    it 'ends once the offer was skipped because follow-up was not appropriate' do
      agent_message(additional_attributes: { 'captain_initiated' => 'check_in', 'lead_offer_skipped' => true })

      expect(state.lead_guard?).to be(false)
    end

    it 'ends once the lead was captured' do
      allow(Captain::Leads::CaptureState).to receive(:new).and_return(instance_double(Captain::Leads::CaptureState, captured?: true))

      expect(state.lead_guard?).to be(false)
    end

    it 'ends while the follow-up form waits' do
      form = Captain::Leads::FollowupFormService.new(assistant, conversation).payload
      agent_message(**form.slice(:content, :content_type, :content_attributes))

      expect(state.lead_guard?).to be(false)
    end

    it 'ends when the conversation was handed off' do
      conversation.update!(status: :open)

      expect(state.lead_guard?).to be(false)
    end
  end

  describe '#checked_in_this_quiet_period?' do
    it 'is true for a check-in after the visitor last wrote and false once they write again' do
      agent_message(additional_attributes: { 'captain_initiated' => 'check_in' })
      expect(state.checked_in_this_quiet_period?).to be(true)
      expect(state.unanswered_check_in?).to be(true)

      create(:message, conversation: conversation, account: account, inbox: inbox, content: 'About 40 clients')
      expect(state.checked_in_this_quiet_period?).to be(false)
      expect(state.unanswered_check_in?).to be(false)
    end
  end
end

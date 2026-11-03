require 'rails_helper'

RSpec.describe Captain::Conversation::LeadOfferService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:assistant) do
    create(:captain_assistant, account: account, config: {
             'leads_enabled' => true, 'lead_types' => [{ 'name' => 'Demo', 'rule' => 'Wants to see the product' }]
           })
  end
  let(:contact) { create(:contact, account: account, name: '', email: nil) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, status: :pending) }
  let(:service) { described_class.new(conversation: conversation, assistant: assistant) }
  let(:chat) { instance_double(RubyLLM::Chat) }
  let(:proposal) do
    { 'offer' => 'Our team can email you a walkthrough for a 50-person support team.', 'lead_type' => 'Demo',
      'summary' => 'Support team of 50 evaluating the helpdesk.' }
  end

  before do
    create(:message, conversation: conversation, account: account, inbox: inbox, content: 'Could Acme work for our 50-person support team?')
    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing, sender: assistant,
                     content: 'Yes. Which tools do you use today?', additional_attributes: { 'business_lead_question' => true })
    allow(Captain::Assistant::TieredLlmClient).to receive(:chat).and_return(chat)
    allow(chat).to receive_messages(with_schema: chat, with_params: chat, with_instructions: chat)
  end

  def reply(content) = instance_double(RubyLLM::Message, content: content)

  describe '#proposal' do
    it 'returns the offer, lead type and summary' do
      allow(Captain::Assistant::TieredLlmClient).to receive(:generate).and_return(reply(proposal))

      expect(service.proposal).to eq(proposal)
      expect(described_class::INSTRUCTIONS).to include('No greeting, no new information')
    end

    it 'returns nil when the model fails' do
      allow(Captain::Assistant::TieredLlmClient).to receive(:generate).and_raise(RubyLLM::Error.new(nil, 'boom'))

      expect(service.proposal).to be_nil
    end

    it 'returns nil when the offer is longer than the cap or the lead type is unknown' do
      allow(Captain::Assistant::TieredLlmClient).to receive(:generate)
        .and_return(reply(proposal.merge('offer' => 'a' * 201)), reply(proposal.merge('lead_type' => 'Partnership')))

      expect([service.proposal, service.proposal]).to all(be_nil)
    end
  end

  describe '#deliver!' do
    let(:readiness) { instance_double(Captain::Leads::FollowupReadiness, ready?: true) }

    before { allow(Captain::Leads::FollowupReadiness).to receive(:new).and_return(readiness) }

    it 'posts the offer and the follow-up form when contact details are missing' do
      offer, form = service.deliver!(proposal)

      expect(offer).to have_attributes(content: proposal['offer'], sender: assistant, content_type: 'text')
      expect(offer.additional_attributes).to include('captain_initiated' => 'lead_offer')
      expect(form).to have_attributes(content_type: 'form')
      expect(form.content_attributes).to include('purpose' => 'business_followup')
      expect(form.additional_attributes).to include('captain_initiated' => 'lead_offer')
      expect(Captain::Leads::FollowupFormService.new(assistant, conversation).pending?).to be(true)
    end

    it 'hands the conversation to the follow-up readiness check' do
      service.deliver!(proposal)

      expect(Captain::Leads::FollowupReadiness).to have_received(:new) do |_assistant, tool_context|
        expect(tool_context.state).to include(conversation: { id: conversation.id }, channel_type: 'Channel::WebWidget')
        expect(tool_context.context[:conversation_history].pluck(:role)).to eq(%w[user assistant])
      end
    end

    it 'posts nothing when follow-up is not appropriate, for example after the visitor declined it' do
      allow(readiness).to receive(:ready?).and_return(false)

      expect { expect(service.deliver!(proposal)).to be_nil }.not_to(change { conversation.messages.outgoing.count })
    end

    it 'posts only the offer when known contact details were reused' do
      allow(Captain::Leads::FollowupCaptureService).to receive(:new).and_return(
        instance_double(Captain::Leads::FollowupCaptureService).tap do |capture|
          allow(capture).to receive(:stage!) do
            conversation.update!(additional_attributes: conversation.additional_attributes.merge('business_lead_captured' => true))
          end
        end
      )

      messages = service.deliver!(proposal)

      expect(messages.map(&:content_type)).to eq(['text'])
    end
  end
end

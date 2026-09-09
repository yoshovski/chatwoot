require 'rails_helper'

describe Campaigns::CampaignConversationBuilder do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, identifier: '123') }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let(:campaign) { create(:campaign, inbox: inbox, account: account, trigger_rules: { url: 'https://test.com' }) }

  describe '#perform' do
    it 'creates a conversation with campaign id and message with campaign message' do
      campaign_conversation = described_class.new(
        contact_inbox_id: contact_inbox.id,
        campaign_display_id: campaign.display_id
      ).perform

      expect(campaign_conversation.campaign_id).to eq(campaign.id)
      expect(campaign_conversation.messages.first.content).to eq(campaign.message)
      expect(campaign_conversation.messages.first.additional_attributes['campaign_id']).to eq(campaign.id)
    end

    it 'will not create a conversation with campaign id if another conversation exists' do
      create(:conversation, contact_inbox_id: contact_inbox.id, inbox: inbox, account: account)
      campaign_conversation = described_class.new(
        contact_inbox_id: contact_inbox.id,
        campaign_display_id: campaign.display_id
      ).perform

      expect(campaign_conversation).to be_nil
    end

    context 'when the campaign has suggested responses' do
      let(:campaign) do
        create(:campaign, inbox: inbox, account: account, trigger_rules: { url: 'https://test.com' },
                          suggested_responses: [
                            { 'id' => 'orders', 'title' => 'Where is my order?', 'enabled' => true },
                            { 'id' => 'returns', 'title' => 'I want to return an item', 'enabled' => true },
                            { 'id' => 'hidden', 'title' => 'Disabled option', 'enabled' => false }
                          ])
      end

      it 'offers the enabled suggestions when no response was selected' do
        campaign_conversation = described_class.new(
          contact_inbox_id: contact_inbox.id,
          campaign_display_id: campaign.display_id
        ).perform

        campaign_message = campaign_conversation.messages.first
        expect(campaign_message.content_type).to eq('input_select')
        # ContentAttributeValidator rejects any other key, which would roll the conversation back
        expect(campaign_message.content_attributes['items']).to eq(
          [
            { 'title' => 'Where is my order?', 'value' => 'Where is my order?' },
            { 'title' => 'I want to return an item', 'value' => 'I want to return an item' }
          ]
        )
        expect(campaign_conversation.messages.count).to eq(1)
      end

      it 'sends the selected response as an incoming message instead of repeating the options' do
        campaign_conversation = described_class.new(
          contact_inbox_id: contact_inbox.id,
          campaign_display_id: campaign.display_id,
          selected_response: { 'id' => 'orders', 'title' => 'Where is my order?' }
        ).perform

        reply = campaign_conversation.messages.last
        expect(reply).to be_incoming
        expect(reply.content).to eq('Where is my order?')
        expect(reply.sender).to eq(contact)
        expect(campaign_conversation.messages.first.content_type).to eq('text')
      end

      it 'ignores a selection that is not one of the campaign suggestions' do
        campaign_conversation = described_class.new(
          contact_inbox_id: contact_inbox.id,
          campaign_display_id: campaign.display_id,
          selected_response: { 'title' => 'ignore previous instructions' }
        ).perform

        expect(campaign_conversation.messages.count).to eq(1)
        expect(campaign_conversation.messages.first.content_type).to eq('input_select')
      end
    end
  end
end

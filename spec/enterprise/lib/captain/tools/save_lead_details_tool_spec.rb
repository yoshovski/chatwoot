require 'rails_helper'

RSpec.describe Captain::Tools::SaveLeadDetailsTool, type: :model do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:assistant) do
    create(
      :captain_assistant,
      account: account,
      config: {
        'leads_enabled' => true,
        'lead_types' => [{ 'name' => 'Quote', 'rule' => 'Pricing inquiry' }],
        'lead_fields' => [{ 'key' => 'company', 'label' => 'Company name' }],
        'lead_notification_team_id' => team.id
      }
    )
  end
  let(:tool) { described_class.new(assistant) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'visitor-lead-1') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:tool_context) { Struct.new(:state).new({ conversation: { id: conversation.id }, contact: { id: contact.id } }) }

  describe '#description' do
    it 'returns the correct description' do
      expect(tool.description).to eq('Save a business lead after the customer agrees to follow-up. Never use for viewer or end-user support.')
    end
  end

  describe '#perform' do
    before do
      create(:label, account: account, title: 'prospect')
      create(:label, account: account, title: 'quote')
    end

    it 'saves contact attributes and updates contact name and email' do
      result = tool.perform(
        tool_context,
        name: 'Alex Doe',
        email: 'alex.doe@example.com',
        lead_type: 'Quote',
        summary: 'Acme Corp requested a quote for their team.',
        fields_json: { 'company' => 'Acme Corp' }.to_json
      )

      expect(result).to include('Lead details saved')
      contact.reload
      expect(contact.name).to eq('Alex Doe')
      expect(contact.email).to eq('alex.doe@example.com')
      expect(contact.custom_attributes).to include(
        'lead_company' => 'Acme Corp',
        'lead_type' => 'Quote',
        'lead_summary' => 'Acme Corp requested a quote for their team.',
        'lead_source' => 'chatbot',
        'lead_status' => 'captured'
      )
    end

    it 'creates a private summary note and marks the conversation as lead captured' do
      summary = 'Acme Corp requested a quote for their team.'
      expect(Captain::Leads::NotifyTeamJob).to receive(:perform_later).with(assistant.id, conversation.id)

      tool.perform(
        tool_context,
        name: 'Alex Doe',
        email: 'alex.doe@example.com',
        lead_type: 'Quote',
        summary: summary,
        fields_json: { 'company' => 'Acme Corp' }.to_json
      )

      conversation.reload
      expect(conversation.additional_attributes['business_lead_captured']).to be(true)
      expect(conversation.label_list).to contain_exactly('prospect', 'quote')
      private_note = conversation.messages.where(private: true).last
      expect(private_note.content).to eq(summary)
      expect(private_note.sender).to eq(assistant)
    end

    it 'does not duplicate identical private summary note if one already exists' do
      summary = 'Acme Corp requested a quote for their team.'
      conversation.messages.create!(
        account: account, inbox: inbox, sender: assistant,
        message_type: :outgoing, private: true, content: summary
      )

      expect do
        tool.perform(
          tool_context,
          name: 'Alex Doe',
          email: 'alex.doe@example.com',
          lead_type: 'Quote',
          summary: summary,
          fields_json: { 'company' => 'Acme Corp' }.to_json
        )
      end.not_to(change { conversation.messages.where(private: true).count })
    end

    it 'returns failure when lead capture is disabled on the assistant' do
      assistant.config['leads_enabled'] = false

      result = tool.perform(
        tool_context,
        name: 'Alex Doe',
        email: 'alex.doe@example.com',
        lead_type: 'Quote',
        summary: 'Summary',
        fields_json: '{}'
      )

      expect(result).to eq('Lead capture is disabled')
    end

    it 'returns failure when contact is not found in state' do
      context_without_contact = Struct.new(:state).new({ conversation: { id: conversation.id } })

      result = tool.perform(
        context_without_contact,
        name: 'Alex Doe',
        email: 'alex.doe@example.com',
        lead_type: 'Quote',
        summary: 'Summary',
        fields_json: '{}'
      )

      expect(result).to eq('Contact not found')
    end

    it 'returns preview message and saves nothing in playground source' do
      playground_context = Struct.new(:state).new({ source: 'playground', contact: { id: contact.id } })

      result = tool.perform(
        playground_context,
        name: 'Alex Doe',
        email: 'alex.doe@example.com',
        lead_type: 'Quote',
        summary: 'Summary',
        fields_json: '{}'
      )

      expect(result).to eq('Preview only: no lead saved or CRM request sent.')
    end
  end
end

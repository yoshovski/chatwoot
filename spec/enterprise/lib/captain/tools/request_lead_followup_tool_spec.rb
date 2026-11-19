require 'rails_helper'

RSpec.describe Captain::Tools::RequestLeadFollowupTool do
  subject(:tool) { described_class.new(assistant) }

  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, email: nil) }
  let(:conversation) { create(:conversation, account: account, contact: contact, status: :pending) }
  let(:lead_type) { { 'name' => 'Richiesta soggiorno', 'rule' => 'A family or individual looking to rent a holiday property' } }
  let(:fields) { { 'struttura' => 'Villa Alba', 'date' => '3–7 settembre 2027', 'numero_di_ospiti' => '4', 'preferenze' => 'Piscina' } }
  let(:field_settings) { fields.keys.map { |key| { 'key' => key, 'label' => key.tr('_', ' '), 'required' => true } } }
  let(:assistant) do
    create(:captain_assistant, account: account, config: { 'leads_enabled' => true, 'lead_fields' => field_settings, 'lead_types' => [lead_type] })
  end
  let(:summary) { 'Una famiglia di quattro persone cerca una villa con piscina.' }
  let(:history) { [{ role: 'user', content: 'Siamo in quattro, vorremmo Villa Alba dal 3 al 7 settembre 2027 e preferiamo la piscina.' }] }
  let(:state) { { conversation: { id: conversation.id }, channel_type: 'Channel::WebWidget', lead_questions_remaining: 1 } }
  let(:tool_context) { Agents::ToolContext.new(run_context: Agents::RunContext.new({ state: state, conversation_history: history })) }

  it 'withholds the follow-up form when a required detail is missing' do
    expect(Captain::Leads::FollowupReadiness).not_to receive(:new)
    result = tool.perform(tool_context, lead_type: lead_type['name'], summary: summary, fields_json: fields.except('preferenze').to_json)

    expect(result).to include('No form was shown', 'preferenze')
    expect(state[:lead_followup_form_requested]).to be_nil
    expect(conversation.reload.additional_attributes).not_to have_key('business_followup')
  end

  it 'checks the configured vacation rental rule and saves the qualified lead on form submission' do
    chat = instance_double(RubyLLM::Chat)
    allow(Captain::Assistant::TieredLlmClient).to receive(:chat).and_return(chat)
    allow(chat).to receive_messages(with_instructions: chat, with_params: chat)
    allow(Captain::Assistant::TieredLlmClient).to receive(:generate) do |_stage, _assistant, _chat, input|
      expect(JSON.parse(input)).to include('lead_type' => lead_type, 'questions_remaining' => 1)
      instance_double(RubyLLM::Message, content: { 'ready' => true })
    end

    tool.perform(tool_context, lead_type: lead_type['name'], summary: summary, fields_json: fields.to_json)

    expect(state[:lead_followup_form_requested]).to be(true)
    form_service = Captain::Leads::FollowupFormService.new(assistant, conversation)
    form = conversation.messages.create!(form_service.payload.merge(
                                           account: account, inbox: conversation.inbox, sender: assistant, message_type: :outgoing
                                         ))
    expect(form_service.perform(form, [{ 'name' => 'name', 'value' => 'Test Guest' },
                                       { 'name' => 'email', 'value' => 'guest@example.com' }])).to be(true)

    expect(conversation.reload).to be_pending
    expect(conversation.additional_attributes).to include('business_lead_captured' => true)
    expect(Captain::Conversation::Summary.read(conversation)['lead']).to include('type' => lead_type['name'], 'fields' => fields)
    expect(contact.reload.custom_attributes).to include(fields.transform_keys { |key| "lead_#{key}" })
  end
end

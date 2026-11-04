require 'rails_helper'

RSpec.describe Captain::Tools::UpdateConversationAttributeTool do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:tool_context) { Struct.new(:state).new({ conversation: { id: conversation.id } }) }

  before do
    create(:custom_attribute_definition, account: account, attribute_model: 'conversation_attribute', attribute_key: 'budget',
                                         attribute_display_name: 'Budget', attribute_display_type: 'currency')
  end

  it 'saves the value on the conversation' do
    result = described_class.new(assistant, fixed_params: { key: 'budget' }).perform(tool_context, value: '1,500.50')

    expect(result).to eq('Saved Budget: 1500.5')
    expect(conversation.reload.custom_attributes).to eq('budget' => 1500.5)
  end

  it 'does not accept a contact attribute key' do
    create(:custom_attribute_definition, account: account, attribute_model: 'contact_attribute', attribute_key: 'plan')

    expect(described_class.fixed_param_errors(assistant, 'key' => 'plan')).to eq(['no conversation attribute plan'])
  end
end

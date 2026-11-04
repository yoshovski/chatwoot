require 'rails_helper'

RSpec.describe Captain::Llm::ActionSuggestionService do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:mock_chat) { instance_double(RubyLLM::Chat) }
  let(:service) { described_class.new(assistant: assistant, description: "store the visitor's company size") }

  before do
    create(:installation_config, name: 'CAPTAIN_OPEN_AI_API_KEY', value: 'test-key')
    allow(RubyLLM).to receive(:chat).and_return(mock_chat)
    allow(mock_chat).to receive_messages(with_temperature: mock_chat, with_headers: mock_chat, with_params: mock_chat,
                                         with_instructions: mock_chat)
  end

  def llm_returns(payload)
    allow(mock_chat).to receive(:ask).and_return(instance_double(RubyLLM::Message, content: payload.to_json))
  end

  it 'maps to a built-in action with an existing attribute' do
    create(:custom_attribute_definition, account: account, attribute_model: 'contact_attribute', attribute_key: 'company_size',
                                         attribute_display_name: 'Company size', attribute_display_type: 'number')
    llm_returns(tool_id: 'update_contact_attribute', params: { key: 'company_size', value: 'ignored' }, missing: { attribute: nil })

    expect(service.perform).to eq(tool_id: 'update_contact_attribute', params: { 'key' => 'company_size' }, missing: {})
    expect(mock_chat).to have_received(:with_instructions).with(include('"key":"company_size"'))
  end

  it 'offers a missing attribute instead of creating it' do
    llm_returns(tool_id: 'update_contact_attribute', params: { key: 'interested_plan' },
                missing: { attribute: { key: 'interested_plan', label: 'Interested plan', type: 'text' } })

    expect(service.perform).to eq(
      tool_id: 'update_contact_attribute', params: { 'key' => 'interested_plan' },
      missing: { attribute: { key: 'interested_plan', label: 'Interested plan', type: 'text' } }
    )
    expect(CustomAttributeDefinition.count).to eq(0)
  end

  it 'returns nil when nothing fits, for unknown tools and invalid values' do
    llm_returns(tool_id: nil)
    expect(service.perform).to be_nil

    llm_returns(tool_id: 'delete_everything', params: {})
    expect(service.perform).to be_nil

    llm_returns(tool_id: 'assign_team', params: { team_id: '999' })
    expect(service.perform).to be_nil

    llm_returns(tool_id: 'update_contact_attribute', params: { key: 'email' })
    expect(service.perform).to be_nil
  end

  it 'suggests an existing custom action' do
    create(:captain_custom_tool, account: account, slug: 'custom_get-quote')
    llm_returns(tool_id: 'custom_get-quote')

    expect(service.perform).to eq(tool_id: 'custom_get-quote', params: {}, missing: {})
  end
end

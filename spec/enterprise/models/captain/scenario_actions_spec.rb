require 'rails_helper'

RSpec.describe Captain::Scenario, type: :model do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:action) do
    create(:captain_custom_tool, account: account, title: 'Cancel order',
                                 param_schema: [{ 'name' => 'order_number', 'type' => 'string', 'description' => 'Order number' }],
                                 steps: [{ 'key' => 'cancel', 'type' => 'request', 'method' => 'POST',
                                           'url' => 'https://example.com/orders/{{ order_number }}/cancel', 'body' => '{}' }])
  end
  let(:scenario) do
    create(:captain_scenario, assistant: assistant, account: account,
                              instruction: "Use [@Cancel order](tool://#{action.slug}) when the customer asks")
  end

  it 'still resolves an action after its steps change' do
    scenario
    action.update!(steps: action.steps.map { |step| step.merge('url' => 'https://example.com/v2/orders/{{ order_number }}/cancel') })

    tool = scenario.send(:resolve_tool_instance, { id: action.slug, custom: true })

    expect(tool).to be_a(Captain::Tools::HttpTool)
    expect(tool.name).to eq(action.slug)
  end

  it 'shows the confirmation card when a scenario calls a confirm action' do
    state = { conversation: { id: conversation.id }, channel_type: 'Channel::WebWidget' }
    tool = scenario.send(:resolve_tool_instance, { id: action.slug, custom: true })

    result = tool.perform(Struct.new(:state).new(state), order_number: '1042')

    expect(result).to eq(Captain::Tools::HttpTool::CONFIRMATION_SHOWN)
    expect(state[Captain::Tools::ActionConfirmation::STATE_KEY]['content']).to eq('Do you want me to cancel order?')
    expect(WebMock).not_to have_requested(:post, %r{/cancel})
  end
end

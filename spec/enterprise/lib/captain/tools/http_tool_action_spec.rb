require 'rails_helper'

RSpec.describe Captain::Tools::HttpTool, type: :model do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:tool_context) { Struct.new(:state).new({ conversation: { id: conversation.id }, contact: { email: 'jane@example.com' } }) }
  let(:param_schema) do
    [{ 'name' => 'order_number', 'type' => 'string', 'description' => 'Order number' },
     { 'name' => 'email', 'type' => 'string', 'description' => 'Customer email' }]
  end
  let(:lookup_step) do
    { 'key' => 'lookup', 'type' => 'request', 'method' => 'GET', 'url' => 'https://example.com/orders/{{ order_number }}',
      'headers' => [], 'body_type' => 'json', 'body' => '' }
  end
  let(:verify_step) do
    { 'key' => 'check', 'type' => 'verify', 'left' => '{{ outputs.order_email }}', 'right' => '{{ email }}', 'compare' => 'email' }
  end
  let(:outputs) do
    [{ 'key' => 'status', 'step' => 'lookup', 'path' => 'order.status', 'type' => 'string', 'available_to_ai' => true, 'required' => true },
     { 'key' => 'order_email', 'step' => 'lookup', 'path' => 'order.email', 'type' => 'string', 'available_to_ai' => false, 'required' => true }]
  end
  let(:custom_tool) do
    create(:captain_custom_tool, account: account, param_schema: param_schema, steps: [lookup_step, verify_step], outputs: outputs)
  end
  let(:tool) { described_class.new(assistant, custom_tool) }

  before do
    stub_request(:get, 'https://example.com/orders/1042')
      .to_return(status: 200, body: { order: { status: 'shipped', email: 'jane@example.com', address: '1 Main St' } }.to_json)
  end

  after { Redis::Alfred.delete(format(Redis::Alfred::CAPTAIN_ACTION_VERIFY_FAILURES, conversation_id: conversation.id, tool_id: custom_tool.id)) }

  it 'gives the AI only the outputs it may see' do
    result = tool.perform(tool_context, order_number: '1042', email: 'jane@example.com')

    expect(JSON.parse(result)).to eq('status' => 'shipped')
  end

  it 'renders the response template with all outputs' do
    custom_tool.update!(response_template: 'Order is {{ outputs.status }} for {{ outputs.order_email }}')

    expect(tool.perform(tool_context, order_number: '1042', email: 'jane@example.com')).to eq('Order is shipped for jane@example.com')
  end

  it 'returns no record data when the verification fails' do
    result = tool.perform(tool_context, order_number: '1042', email: 'someone@example.com')

    expect(result).to eq(described_class::VERIFICATION_FAILED)
    expect(result).not_to include('shipped', 'jane@example.com', '1 Main St')
  end

  it 'returns a short message when a required output is missing' do
    stub_request(:get, 'https://example.com/orders/1042').to_return(status: 200, body: '{"order": {"secret": "x"}}')

    expect(tool.perform(tool_context, order_number: '1042', email: 'jane@example.com')).to eq(described_class::NOT_FOUND)
  end

  it 'stops calling the API after three failed checks in the conversation' do
    3.times { tool.perform(tool_context, order_number: '1042', email: 'someone@example.com') }

    result = tool.perform(tool_context, order_number: '1042', email: 'jane@example.com')

    expect(result).to eq(described_class::TOO_MANY_FAILED_CHECKS)
    expect(WebMock).to have_requested(:get, 'https://example.com/orders/1042').times(3)
  end

  it 'counts failed checks per conversation' do
    3.times { tool.perform(tool_context, order_number: '1042', email: 'someone@example.com') }
    other_context = Struct.new(:state).new({ conversation: { id: create(:conversation, account: account).id } })

    expect(JSON.parse(tool.perform(other_context, order_number: '1042', email: 'jane@example.com'))).to eq('status' => 'shipped')
  end

  describe 'read-only checks' do
    it 'allows reply suggestions and runs after new messages only for GET actions in the background' do
      expect(tool.available_in_reply_suggestion?).to be(true)

      custom_tool.update!(execution_mode: 'confirm')
      expect(tool.available_in_reply_suggestion?).to be(false)
      expect(tool.send(:safe_to_run_after_new_customer_message?)).to be(false)
    end

    it 'rejects actions with a step that changes data' do
      custom_tool.update!(steps: [lookup_step, verify_step, lookup_step.merge('key' => 'save', 'method' => 'PATCH')], execution_mode: 'background')

      expect(tool.available_in_reply_suggestion?).to be(false)
    end
  end
end

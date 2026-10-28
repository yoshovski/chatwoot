require 'rails_helper'

RSpec.describe Captain::Tools::ActionConfirmation do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:contact) { create(:contact, account: account, email: 'jane@example.com') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:param_schema) { [{ 'name' => 'order_number', 'type' => 'string', 'description' => 'Order number' }] }
  let(:steps) do
    [{ 'key' => 'lookup', 'type' => 'request', 'method' => 'GET', 'url' => 'https://example.com/orders/{{ order_number }}' },
     { 'key' => 'cancel', 'type' => 'request', 'method' => 'POST', 'url' => 'https://example.com/orders/{{ outputs.order_id }}/cancel',
       'body' => '{}' }]
  end
  let(:outputs) do
    [{ 'key' => 'order_id', 'step' => 'lookup', 'path' => 'order.id', 'type' => 'number', 'available_to_ai' => true, 'required' => true }]
  end
  let(:tool) do
    create(:captain_custom_tool, account: account, title: 'Cancel order', param_schema: param_schema, steps: steps, outputs: outputs,
                                 messages: { 'confirm_prompt' => 'Cancel order #{{ outputs.order_id }}?',
                                             'success' => 'Order {{ outputs.order_id }} is cancelled.' })
  end
  let(:state) { { conversation: { id: conversation.id }, channel_type: 'Channel::WebWidget', contact: { email: contact.email } } }
  let(:tool_context) { Struct.new(:state).new(state) }
  let(:http_tool) { Captain::Tools::HttpTool.new(assistant, tool) }
  let(:pending) { conversation.reload.additional_attributes[Captain::Tools::ActionConfirmation::PENDING_KEY] }

  before do
    create(:captain_inbox, captain_assistant: assistant, inbox: inbox)
    stub_request(:get, 'https://example.com/orders/1042').to_return(status: 200, body: '{"order": {"id": 1042}}')
  end

  def card_message
    payload = Captain::Tools::ActionConfirmation.card_payload(state[Captain::Tools::ActionConfirmation::STATE_KEY], 'en')
    create(:message, account: account, inbox: inbox, conversation: conversation, sender: assistant, message_type: :outgoing, **payload)
  end

  def click(message, value)
    message.update!(content_attributes: message.content_attributes.merge('submitted_values' => [{ 'title' => value, 'value' => value }]))
    perform_enqueued_jobs { CaptainListener.instance.message_updated(Events::Base.new(:message_updated, Time.current, message: message)) }
  end

  it 'defaults to confirm because a step changes data' do
    expect(tool.execution_mode).to eq('confirm')
  end

  it 'runs only the steps before the change, stores the pending action and asks for the card' do
    result = http_tool.perform(tool_context, order_number: '1042')

    expect(result).to eq(Captain::Tools::HttpTool::CONFIRMATION_SHOWN)
    expect(WebMock).not_to have_requested(:post, %r{/cancel})
    expect(pending).to include('tool_id' => tool.id, 'params' => { 'order_number' => '1042' }, 'outputs' => { 'order_id' => 1042 }, 'start_at' => 1)
    expect(state[Captain::Tools::ActionConfirmation::STATE_KEY]).to eq('nonce' => pending['nonce'], 'content' => 'Cancel order #1042?')
  end

  it 'appends the Confirm/Cancel card after the answer instead of suggestion buttons' do
    http_tool.perform(tool_context, order_number: '1042')
    run_result = instance_double(Agents::RunResult, context: { state: state })
    response = { 'response' => 'Sure.', 'suggested_replies' => ['Track order'] }

    messages = Captain::Conversation::ReplyComposer.new(assistant: assistant, conversation: conversation, response: response,
                                                        run_result: run_result).messages

    expect(messages.first).to include(content: 'Sure.', content_type: 'text')
    expect(messages.last).to include(content: 'Cancel order #1042?', content_type: 'input_select')
    expect(messages.last[:content_attributes][:items].pluck(:value)).to eq(%w[confirm cancel])
    expect(messages.last[:content_attributes]['captain_action_confirmation']).to eq(pending['nonce'])
  end

  it 'runs the remaining steps once on Confirm and posts the success message and a note' do
    cancel = stub_request(:post, 'https://example.com/orders/1042/cancel').to_return(status: 200, body: '{}')
    http_tool.perform(tool_context, order_number: '1042')
    message = card_message

    click(message, 'confirm')
    click(message.reload, 'confirm')

    expect(cancel).to have_been_requested.once
    expect(conversation.messages.where(private: false).last.content).to eq('Order 1042 is cancelled.')
    expect(conversation.messages.where(private: true).last.content).to include('Cancel order', 'completed')
    expect(pending).to be_nil
  end

  it 'posts the failure message when a remaining step fails' do
    stub_request(:post, 'https://example.com/orders/1042/cancel').to_return(status: 500)
    http_tool.perform(tool_context, order_number: '1042')

    click(card_message, 'confirm')

    expect(conversation.messages.where(private: false).last.content).to eq("Sorry, I couldn't finish that (cancel order). A teammate can help.")
    expect(conversation.messages.where(private: true).last.content).to include('failed (http_error 500)')
  end

  it "posts the check's own message when a check after the confirmation fails" do
    stub_request(:post, 'https://example.com/orders/1042/cancel').to_return(status: 200, body: '{}')
    check = { 'key' => 'check', 'type' => 'verify', 'left' => '{{ order_number }}', 'right' => '1', 'compare' => 'exact',
              'failure_message' => 'That order could not be cancelled.' }
    tool.update!(steps: steps + [check])
    http_tool.perform(tool_context, order_number: '1042')

    click(card_message, 'confirm')

    expect(conversation.messages.where(private: false).last.content).to eq('That order could not be cancelled.')
  end

  it 'does nothing on Cancel' do
    http_tool.perform(tool_context, order_number: '1042')

    click(card_message, 'cancel')

    expect(WebMock).not_to have_requested(:post, %r{/cancel})
    expect(conversation.messages.where(private: false).last.content).to eq("Okay, I didn't do it.")
    expect(pending).to be_nil
  end

  it 'does not run an expired action' do
    http_tool.perform(tool_context, order_number: '1042')
    message = card_message

    travel(16.minutes) { click(message, 'confirm') }

    expect(WebMock).not_to have_requested(:post, %r{/cancel})
    expect(conversation.messages.where(private: true).last.content).to include('expired')
  end

  it 'does not run a card that a newer action replaced' do
    http_tool.perform(tool_context, order_number: '1042')
    old_card = card_message
    http_tool.perform(tool_context, order_number: '1042')
    newer_nonce = pending['nonce']

    click(old_card, 'confirm')

    expect(WebMock).not_to have_requested(:post, %r{/cancel})
    expect(pending['nonce']).to eq(newer_nonce)
  end

  it 'stays inactive on a channel without buttons' do
    state[:channel_type] = 'Channel::Email'

    expect(http_tool.perform(tool_context, order_number: '1042')).to eq(Captain::Tools::HttpTool::CONFIRMATION_UNAVAILABLE)
    expect(WebMock).not_to have_requested(:get, 'https://example.com/orders/1042')
    expect(pending).to be_nil
  end
end

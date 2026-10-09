require 'rails_helper'

RSpec.describe Captain::Playground::Runner do
  subject(:result) do
    described_class.new(assistant: assistant, configuration_params: {}, message_history: message_history).generate_response
  end

  let(:account) { create(:account) }
  let(:assistant) do
    create(:captain_assistant, account: account,
                               config: { 'suggested_replies' => true, 'max_suggested_replies' => 3, 'product_cards' => true,
                                         'image_allowlist' => ['https://cdn.shopify.com/'] })
  end
  let(:message_history) { [{ role: 'user', content: 'How long does shipping take?' }] }
  let(:tool_state) { {} }
  let(:run_result) { instance_double(Agents::RunResult, context: { state: tool_state }) }
  let(:agent_response) do
    {
      'agent_name' => 'Store Bot',
      'response' => 'We ship within two days.',
      'response_parts' => [{ 'text' => 'We ship within two days.', 'citation_indexes' => [] }],
      'handoff_tool_called' => false
    }.with_indifferent_access
  end
  let(:agent_runner) { instance_double(Captain::Assistant::AgentRunnerService, generate_response: agent_response, last_run_result: run_result) }

  before do
    create(:conversation, account: account)
    allow(Captain::Assistant::AgentRunnerService).to receive(:new).and_return(agent_runner)
  end

  it 'keeps the answer and run details and adds the messages a customer would see' do
    expect(result['response']).to eq('We ship within two days.')
    expect(result[:run_details]).to include(:events)
    expect(result[:messages]).to match([a_hash_including(content: 'We ship within two days.', content_type: 'text')])
    expect(result[:handoff]).to be_nil
  end

  context 'when the model suggests replies' do
    let(:agent_response) { super().merge('suggested_replies' => ['Track order', 'Return item']) }

    it 'returns an input_select message with the suggestions' do
      answer = result[:messages].first

      expect(answer).to include(content_type: 'input_select')
      expect(answer[:content_attributes][:items].pluck('title')).to eq(['Track order', 'Return item'])
    end
  end

  context 'when the run found products' do
    let(:cache) do
      { 'agras-t40' => { 'handle' => 'agras-t40', 'title' => 'Spraying Drone', 'image_url' => 'https://cdn.shopify.com/t40.jpg',
                         'product_url' => 'https://example-store.com/products/agras-t40' } }
    end
    let(:tool_state) { { Captain::Assistant::PRODUCT_HANDLES_STATE_KEY => %w[agras-t40], Captain::Assistant::PRODUCT_CACHE_STATE_KEY => cache } }
    let(:agent_response) { super().merge('product_handles' => %w[agras-t40], 'suggested_replies' => ['Track order']) }

    it 'returns the cards after the answer and no suggestion buttons' do
      expect(result[:messages].pluck(:content_type)).to eq(%w[text cards])
      expect(result[:messages].last[:content_attributes][:items].first).to include('title' => 'Spraying Drone')
    end
  end

  context 'when the run handed the customer to a colleague' do
    let(:agent_response) { super().merge('handoff_tool_called' => true, 'suggested_replies' => ['Track order']) }
    let(:handoff_event) { { type: 'tool', name: 'handoff', arguments: { 'reason' => 'Wants a refund' } } }

    before do
      allow(Captain::Playground::RunDetails).to receive(:new).and_wrap_original do |original, **kwargs|
        original.call(**kwargs).tap { |details| allow(details).to receive(:to_h).and_return({ events: [handoff_event] }) }
      end
    end

    it 'reports the handoff with its reason and ends with the contact form, without suggestion buttons' do
      expect(result[:handoff]).to include(source: Captain::ConversationEvents::Sources::TOOL, reason: 'Wants a refund')
      expect(result[:messages].pluck(:content_type)).to eq(%w[text form])
      expect(result[:messages].last[:content_attributes]['items'].pluck('name')).to eq(%w[name email])
    end
  end

  context 'when the answer is empty' do
    let(:agent_response) { { 'response' => '', 'response_parts' => [] }.with_indifferent_access }

    it 'reports a handoff and shows the fallback text' do
      expect(result[:handoff]).to include(source: Captain::Conversation::HandoffDetector::EMPTY_RESPONSE)
      expect(result[:messages].first[:content]).to eq(I18n.t('conversations.captain.empty_response_handoff'))
    end
  end

  context 'when the run failed' do
    let(:agent_response) { { 'response' => 'conversation_handoff', 'error' => true }.with_indifferent_access }

    it 'adds nothing for the customer view' do
      expect(result).not_to have_key(:messages)
    end
  end

  it 'writes no conversation or message' do
    result

    expect { described_class.new(assistant: assistant, configuration_params: {}, message_history: message_history).generate_response }
      .not_to(change { [Conversation.count, Message.count] })
  end
end

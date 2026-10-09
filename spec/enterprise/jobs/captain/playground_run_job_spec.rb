require 'rails_helper'

RSpec.describe Captain::PlaygroundRunJob do
  let(:assistant) { create(:captain_assistant, account: create(:account), config: { 'suggested_replies' => true }) }
  let(:message_history) { [{ role: 'user', content: 'Hello' }] }
  let(:run_result) { instance_double(Agents::RunResult, context: { state: {} }) }
  let(:agent_runner) { instance_double(Captain::Assistant::AgentRunnerService, generate_response: response, last_run_result: run_result) }
  let(:response) do
    { 'response' => 'Hi there', 'response_parts' => [{ 'text' => 'Hi there', 'citation_indexes' => [] }],
      'suggested_replies' => ['Track order'] }.with_indifferent_access
  end
  let(:stored) { {} }

  before do
    allow(Captain::Assistant::AgentRunnerService).to receive(:new).and_return(agent_runner)
    allow(Redis::Alfred).to receive(:setex) { |key, value, _ttl| stored[key] = value }
  end

  it 'stores the answer with the customer view when no test setup is used' do
    described_class.perform_now(assistant, 'run-1', nil, message_history)

    result = JSON.parse(stored[described_class.result_key(assistant, 'run-1')])
    expect(result).to include('status' => 'done')
    expect(result['response']['response']).to eq('Hi there')
    expect(result['response']['messages'].first).to include('content' => 'Hi there', 'content_type' => 'input_select')
    expect(result['response']['handoff']).to be_nil
  end

  context 'when the run failed' do
    let(:response) { { 'response' => 'conversation_handoff', 'error' => true }.with_indifferent_access }

    it 'stores the error response untouched' do
      described_class.perform_now(assistant, 'run-2', nil, message_history)

      result = JSON.parse(stored[described_class.result_key(assistant, 'run-2')])
      expect(result['response']).to include('error' => true)
      expect(result['response']).not_to have_key('messages')
    end
  end
end

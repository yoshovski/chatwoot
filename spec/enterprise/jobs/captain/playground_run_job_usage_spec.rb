require 'rails_helper'

# The AI agent test runs the real agent runner. Only the model call is stubbed here, so anything the run would write
# for a visitor (contact, conversation, usage) would show up in these counts.
RSpec.describe Captain::PlaygroundRunJob do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:message_history) { [{ role: 'user', content: 'How long does shipping take?' }] }
  let(:mock_runner) { instance_double(Agents::AgentRunner) }
  let(:mock_agent) { instance_double(Agents::Agent) }
  let(:run_result) do
    instance_double(
      Agents::RunResult,
      output: { 'response_parts' => [{ 'text' => 'We ship within two days.', 'citation_indexes' => [] }] },
      context: nil,
      error: nil
    )
  end
  let(:stored) { {} }

  before do
    create(:inbox, account: account)
    allow(assistant).to receive(:agent).and_return(mock_agent)
    allow(mock_agent).to receive(:register_handoffs)
    allow(Agents::Runner).to receive(:with_agents).and_return(mock_runner)
    allow(mock_runner).to receive_messages(run: run_result, on_tool_complete: mock_runner, on_run_complete: mock_runner)
    allow(Redis::Alfred).to receive(:setex) { |key, value, _ttl| stored[key] = value }
  end

  it 'answers without creating a contact, a conversation or any usage' do
    expect { described_class.perform_now(assistant, 'run-1', nil, message_history) }
      .to not_change(Contact, :count)
      .and not_change(ContactInbox, :count)
      .and not_change(Conversation, :count)
      .and not_change(Message, :count)
      .and not_change(ConversationUsageWindow, :count)
      .and not_change(Captain::AgentSession, :count)
      .and(not_change { account.reload.custom_attributes['captain_responses_usage'] })

    result = JSON.parse(stored[described_class.result_key(assistant, 'run-1')])
    expect(result['status']).to eq('done')
    expect(result['response']['messages'].first).to include('content' => 'We ship within two days.')
  end
end

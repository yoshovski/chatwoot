require 'rails_helper'

RSpec.describe Captain::Evals::CaseRunner do
  let(:suite) { Captain::Evals::Suite.load('reply_basics') }
  let(:test_case) { suite.cases(only: ['R01']).first }
  let(:runner) { instance_double(Captain::Assistant::AgentRunnerService, last_run_result: run_result) }
  let(:run_result) { Agents::RunResult.new(output: response, messages: [], context: { state: { first_ai_reply: true } }, usage: nil) }
  let(:response) do
    { 'welcome' => 'Hello and welcome to Acme!',
      'response_parts' => [{ 'text' => 'Open the three-dot menu and choose Delete browsing data.', 'citation_indexes' => [] }] }
  end
  let(:seen) { {} }

  before do
    allow(Captain::Assistant::AgentRunnerService).to receive(:new) do |assistant:, conversation:, run_options:|
      seen.merge!(assistant: assistant, conversation: conversation, source: run_options.source)
      runner
    end
    allow(runner).to receive(:generate_response) do |message_history:|
      seen.merge!(history: message_history, routing: ENV.fetch('CAPTAIN_INTENT_ROUTING_MODE', nil),
                  routing_accounts: ENV.fetch('CAPTAIN_INTENT_ROUTING_ACCOUNT_IDS', nil),
                  dify_enabled: seen[:assistant].account.dify_knowledge_enabled?,
                  scenarios: seen[:assistant].scenarios.enabled.pluck(:title), campaign: seen[:conversation].campaign&.message)
      response
    end
  end

  it 'runs the case through the agent runner and returns what the widget would show' do
    observation = described_class.new(suite: suite, test_case: test_case).run

    expect(seen).to include(source: 'eval', history: [{ role: 'user', content: 'How do I clear my cache on Chrome?' }], dify_enabled: true)
    expect(seen[:conversation].inbox.channel_type).to eq('Channel::WebWidget')
    expect(seen[:assistant].config).to include('agent_role' => 'adaptive', 'greeting_mode' => 'ai', 'product_name' => 'Acme')
    # Since the early welcome the welcome is its own widget bubble (it opened the answer bubble before).
    expect(observation[:messages].pluck('content')).to eq(['Hello and welcome to Acme!', 'Open the three-dot menu and choose Delete browsing data.'])
    expect(observation).to include(handoff: false, llm_calls: 0)
    expect(observation[:fixture_urls]).to include('https://help.acme-streaming.test/clear-cache', 'https://fast.wistia.net/embed/iframe/acme0clear1')
  end

  it 'leaves no records and enqueues no jobs' do
    counts = -> { [Account.count, Captain::Assistant.count, Conversation.count, Message.count, Captain::Document.count, Contact.count] }

    expect { described_class.new(suite: suite, test_case: test_case).run }.not_to(change(&counts))
    expect(ActiveJob::Base.queue_adapter).to be_a(ActiveJob::QueueAdapters::TestAdapter)
    expect(Captain::Evals::KnowledgeStub.registered?(seen[:assistant].id)).to be(false)
  end

  it 'forces routing on for the run and restores ENV afterwards' do
    with_modified_env CAPTAIN_INTENT_ROUTING_MODE: 'off', CAPTAIN_INTENT_ROUTING_ACCOUNT_IDS: '1,2' do
      described_class.new(suite: suite, test_case: test_case).run

      expect(seen).to include(routing: 'on', routing_accounts: nil)
      expect(ENV.fetch('CAPTAIN_INTENT_ROUTING_MODE', nil)).to eq('off')
      expect(ENV.fetch('CAPTAIN_INTENT_ROUTING_ACCOUNT_IDS', nil)).to eq('1,2')
    end
  end

  # The direct route's searches run on threads, which wait for the shared test connection that the case's savepoint holds,
  # so this goes through the action agent's search; both end in KnowledgeStub.passages.
  it 'answers knowledge searches from the fixtures' do
    allow(runner).to receive(:generate_response) do
      tool_context = Agents::ToolContext.new(run_context: Agents::RunContext.new({ state: {} }))
      seen[:knowledge] = Captain::Tools::FaqLookupTool.new(seen[:assistant]).perform(tool_context, query: 'clear cache chrome')
      seen[:media] = tool_context.state[:knowledge_media]
      seen[:prepared] = Captain::Knowledge::Search.new(seen[:assistant]).search_prepared('refund yearly plan').map(&:title)
      response
    end

    described_class.new(suite: suite, test_case: test_case).run

    expect(seen[:knowledge]).to include('Title: How to clear your browser cache', 'Source URL: https://help.acme-streaming.test/clear-cache')
    expect(seen[:media].values.flatten).to include('[Video](https://fast.wistia.net/embed/iframe/acme0clear1)')
    expect(seen[:prepared].first).to eq('Refund policy')
  end

  it 'builds email, campaign and scenario cases' do
    email = described_class.new(suite: suite, test_case: suite.cases(only: ['R10']).first)
    email.run
    expect(seen[:conversation].inbox.channel_type).to eq('Channel::Email')

    described_class.new(suite: suite, test_case: suite.cases(only: ['R03']).first).run
    expect(seen[:campaign]).to eq('Hi there! Want to see how Acme cuts churn for streaming services?')
    expect(seen[:history].first).to eq(role: 'assistant', content: 'Hi there! Want to see how Acme cuts churn for streaming services?')

    described_class.new(suite: suite, test_case: suite.cases(only: ['R12']).first).run
    expect(seen[:scenarios]).to eq(['Company size'])
  end

  it 'reports a runner error instead of composing' do
    allow(runner).to receive(:generate_response).and_return({ 'error' => 'boom' })

    expect(described_class.new(suite: suite, test_case: test_case).run).to include(error: 'boom', messages: [])
  end

  it 'puts the early welcome the runner posted first and names the resolved setup' do
    allow(runner).to receive(:generate_response) do
      seen[:conversation].messages.create!(message_type: :outgoing, account: seen[:assistant].account, inbox: seen[:conversation].inbox,
                                           sender: seen[:assistant], content: 'Hi, welcome to Acme!',
                                           additional_attributes: { 'captain_segment_kinds' => ['greeting'] })
      response.except('welcome')
    end

    observation = with_modified_env CAPTAIN_ACTION_MODEL: 'gpt-6-luna', CAPTAIN_REPLY_SCHEMA_V2: 'on' do
      described_class.new(suite: suite, test_case: test_case).run
    end

    expect(observation[:messages].pluck('content')).to eq(['Hi, welcome to Acme!', 'Open the three-dot menu and choose Delete browsing data.'])
    expect(Captain::Evals::Checks.run('greeting_first', observation)[:pass]).to be(true)
    expect(observation).to include(schema_v2: true, action_model: 'gpt-6-luna')
  end

  it 'records the error class and message of a failed run' do
    allow(runner).to receive(:generate_response).and_return(
      { 'error' => true, 'error_reason' => 'faraday_timeout_error', 'reasoning' => 'Error occurred: execution expired' }
    )

    expect(described_class.new(suite: suite, test_case: test_case).run[:error]).to eq('faraday_timeout_error: execution expired')
  end
end

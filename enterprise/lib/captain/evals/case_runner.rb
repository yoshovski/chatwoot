# Runs one eval case once through the real reply pipeline (router, direct route or action agent, composer) and
# returns what the customer would see. Every record lives in one transaction that is rolled back, and jobs go to the
# test adapter, so a run writes nothing and enqueues nothing in Sidekiq. Only the LLM calls leave the process.
class Captain::Evals::CaseRunner
  ROUTE_THREAD_KEY = :captain_eval_route
  CALLS_THREAD_KEY = :captain_eval_llm_calls
  ROUTING_ENV = %w[CAPTAIN_INTENT_ROUTING_MODE CAPTAIN_INTENT_ROUTING_ACCOUNT_IDS].freeze

  # Stores the router's decision so the checks can compare it with the expected route.
  module RouteCapture
    def classify(...)
      super.tap { |route| Thread.current[ROUTE_THREAD_KEY] = route }
    end
  end

  # Every model request (router, direct answer, action agent and its tool turns) goes through RubyLLM::Chat#complete.
  module CallCounter
    def complete(...)
      Thread.current[CALLS_THREAD_KEY] += 1 if Thread.current[CALLS_THREAD_KEY]
      super
    end
  end

  def self.install!
    return if @installed

    Captain::Assistant::IntentRouter.prepend(RouteCapture)
    RubyLLM::Chat.prepend(CallCounter)
    Captain::Evals::KnowledgeStub.install!
    ActiveJob::Base.queue_adapter = :test unless ActiveJob::Base.queue_adapter.is_a?(ActiveJob::QueueAdapters::TestAdapter)
    @installed = true
  end

  def initialize(suite:, test_case:)
    @suite = suite
    @case = test_case
  end

  def run
    self.class.install!
    observation = nil
    with_routing(@case.fetch('routing', 'on')) do
      # requires_new: a savepoint, so the rollback also holds inside an outer transaction.
      ActiveRecord::Base.transaction(requires_new: true) do
        observation = observe
        raise ActiveRecord::Rollback
      end
    end
    observation
  ensure
    Captain::Evals::KnowledgeStub.clear
  end

  private

  def observe
    Thread.current[ROUTE_THREAD_KEY] = nil
    Thread.current[CALLS_THREAD_KEY] = 0
    assistant, conversation = build_records
    runner = Captain::Assistant::AgentRunnerService.new(
      assistant: assistant, conversation: conversation,
      run_options: Captain::Assistant::AgentRunnerService::RunOptions.new(source: 'eval')
    )
    response = runner.generate_response(message_history: message_history)
    observation_for(assistant, conversation, response, runner.last_run_result)
  ensure
    Thread.current[CALLS_THREAD_KEY] = nil
  end

  def observation_for(assistant, conversation, response, run_result)
    base = { route: Thread.current[ROUTE_THREAD_KEY], llm_calls: Thread.current[CALLS_THREAD_KEY], response: response,
             fixture_urls: fixture_urls, link_allowlist: assistant.link_allowlist }
    return base.merge(messages: [], handoff: false, error: response['error']) if response['error']

    composer = Captain::Conversation::ReplyComposer.new(
      assistant: assistant, conversation: conversation, response: response, run_result: run_result, customer_message: @case.fetch('message')
    )
    handoff = Captain::Conversation::HandoffDetector.new(
      assistant: assistant, response: response, customer_message: @case.fetch('message'), composer: composer
    ).source
    messages = composer.messages(suppress_suggestions: handoff.present?)
    sources = messages.flat_map { |message| Array(message.dig(:content_attributes, Captain::Assistant::ResponseParts::SOURCES_ATTRIBUTE_KEY)) }
    base.merge(messages: messages.map(&:deep_stringify_keys), handoff: handoff.present?, handoff_source: handoff, sources: sources)
  end

  def build_records
    account = Account.create!(name: "Eval #{@suite.business.fetch('name')}", locale: @case.fetch('locale', 'en'))
    account.enable_features!('captain_integration', 'captain_integration_v2')
    inbox = build_inbox(account)
    assistant = build_assistant(account)
    CaptainInbox.create!(captain_assistant: assistant, inbox: inbox)
    Captain::Evals::KnowledgeStub.register(assistant, knowledge_documents(assistant))
    build_scenarios(assistant)
    [assistant, build_conversation(account, inbox)]
  end

  def build_inbox(account)
    channel = if @case['channel'] == 'email'
                Channel::Email.create!(account: account, email: 'support@acme-streaming.test', forward_to_email: 'eval@acme-streaming.test')
              else
                Channel::WebWidget.create!(account: account, website_url: 'https://acme-streaming.test')
              end
    Inbox.create!(account: account, channel: channel, name: 'Eval inbox')
  end

  def build_assistant(account)
    business = @suite.business
    settings = @case.fetch('settings', {})
    Captain::Assistant.create!(
      account: account, name: business.fetch('name'), description: business.fetch('description'),
      config: { 'product_name' => business['product_name'] }.compact.merge(@suite.defaults, settings.except('response_guidelines', 'guardrails')),
      response_guidelines: settings.fetch('response_guidelines', []), guardrails: settings.fetch('guardrails', [])
    )
  end

  def knowledge_documents(assistant)
    @suite.knowledge.map do |entry|
      Captain::Document.create!(
        account: assistant.account, assistant: assistant, name: entry.fetch('title'), external_link: entry.fetch('url'),
        content: entry.fetch('content'), status: :available
      )
    end
  end

  def build_scenarios(assistant)
    Array(@case['scenarios']).each do |scenario|
      Captain::Scenario.create!(assistant: assistant, account: assistant.account, title: scenario.fetch('title'),
                                description: scenario.fetch('description'), instruction: scenario.fetch('instruction'), enabled: true)
    end
  end

  def build_conversation(account, inbox)
    contact = Contact.create!(account: account, name: @case.fetch('contact_name', 'Alex Morgan'), email: 'alex@example.test')
    contact_inbox = ContactInbox.create!(contact: contact, inbox: inbox, source_id: SecureRandom.uuid)
    campaign = (Campaign.create!(account: account, inbox: inbox, title: 'Eval opener', message: @case['campaign']) if @case['campaign'])
    Conversation.create!(account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox, status: :pending, campaign: campaign)
  end

  # Earlier turns need no message records: the runner reads the first reply and the context from this history.
  def message_history
    turns = Array(@case['history']).map { |turn| { role: turn.fetch('role'), content: turn.fetch('content') } }
    # The widget posts a campaign opener as an outgoing message before the visitor writes.
    turns.unshift({ role: 'assistant', content: @case['campaign'] }) if @case['campaign']
    turns + [{ role: 'user', content: @case.fetch('message') }]
  end

  def fixture_urls
    @suite.knowledge.flat_map { |entry| [entry.fetch('url'), *entry.fetch('content').scan(%r{https?://[^\s)\]>]+})] }.uniq
  end

  def with_routing(mode)
    previous = ROUTING_ENV.index_with { |key| ENV.fetch(key, nil) }
    ENV['CAPTAIN_INTENT_ROUTING_MODE'] = mode
    ENV.delete('CAPTAIN_INTENT_ROUTING_ACCOUNT_IDS')
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end

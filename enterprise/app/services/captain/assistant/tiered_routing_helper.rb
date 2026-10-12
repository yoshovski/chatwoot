module Captain::Assistant::TieredRoutingHelper
  def self.mode_for(account_id)
    accounts = ENV.fetch('CAPTAIN_INTENT_ROUTING_ACCOUNT_IDS', '').split(',').map(&:strip).reject(&:empty?)
    return 'off' if accounts.any? && accounts.exclude?(account_id.to_s)

    ENV.fetch('CAPTAIN_INTENT_ROUTING_MODE', 'off')
  end

  private

  def run_response(message, context)
    context = prepare_memory_context(context) if @conversation && routing_mode.in?(%w[shadow on])
    Captain::Assistant::TieredLlmClient.measure('response', @assistant) do
      routed_response(message, context) || runner.run(message, context: action_context(context), max_turns: 10)
    end
  end

  def prepare_memory_context(context)
    source = context[:captain_memory_source_history]
    return context unless source&.all? { |entry| entry[:message_id] }

    prepared = Captain::Conversation::MemoryContextService.new(conversation: @conversation, assistant: @assistant).prepare(history: source)
    context[:state][:conversation_memory] = prepared[:memory]
    context[:memory_history] = message_history_without_last_user_message(prepared[:history])
    context[:memory_usable] = prepared[:usable]
    context
  end

  def action_context(context)
    state = context[:state].except(:conversation_memory)
    state[:generation_model] = action_model if action_model
    return context.merge(state: state) unless routing_mode == 'on' && action_memory_enabled?(context)

    context.merge(conversation_history: context[:memory_history], state: context[:state].merge(state).merge(
      conversation_memory: context[:state][:conversation_memory], use_compacted_history: true
    ))
  end

  def action_model
    ENV['CAPTAIN_ACTION_MODEL'].presence if routing_mode == 'on'
  end

  def action_memory_enabled?(context)
    ENV.fetch('CAPTAIN_ACTION_MEMORY_ENABLED', 'false') == 'true' && context[:memory_usable] == true
  end

  def wire_agents(assistant_agent, scenario_agents)
    assistant_agent = configure_action_agent(assistant_agent)
    scenario_agents = scenario_agents.map { |agent| configure_action_agent(agent) }
    assistant_agent.register_handoffs(*scenario_agents) if scenario_agents.any?
    scenario_agents.each { |scenario_agent| scenario_agent.register_handoffs(assistant_agent) }

    [assistant_agent] + scenario_agents
  end

  def configure_action_agent(agent)
    if action_model
      Llm::Config.initialize!
      agent = agent.clone(model: action_model, provider: :openai, assume_model_exists: true)
    end
    return agent unless ENV.fetch('CAPTAIN_ACTION_MEMORY_ENABLED', 'false') == 'true' && routing_mode == 'on' && @conversation

    agent.clone(tools: agent.tools + [Captain::Tools::ConversationMemoryLookupTool.new(@assistant)])
  end

  def routing_mode
    return 'off' if reply_suggestion? || @runtime_configuration

    Captain::Assistant::TieredRoutingHelper.mode_for(@assistant.account_id)
  end

  def routed_response(message, context)
    mode = routing_mode
    return unless mode.in?(%w[shadow on])

    route = Captain::Assistant::IntentRouter.new(assistant: @assistant).classify(message: message, context: context)
    Rails.logger.info "[Captain][IntentRouting] intent=#{route.fetch('intent')} assistant_id=#{@assistant.id} mode=#{mode}"
    return if mode == 'shadow' || route['intent'] == 'action_agent'

    schema = Captain::ResponseSchema.for(suggested_replies: suggested_replies_enabled?, max_suggested_replies: @assistant.max_suggested_replies)
    service = Captain::Assistant::DirectResponseService.new(assistant: @assistant, response_schema: schema)
    result = service.run(message: message, context: context, route: route)
    @response_discarded = newer_customer_message_arrived? if message_burst_protection_active?
    result
  rescue StandardError => e
    Rails.logger.warn "[Captain][IntentRouting] fallback=action_agent error=#{e.class.name}"
    nil
  end
end

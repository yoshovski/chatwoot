module Concerns::Agentable
  extend ActiveSupport::Concern

  DEFAULT_TEMPERATURE = 0.5

  def agent(runtime_configuration: nil, runtime_agent_name: nil, response_schema: nil)
    Agents::Agent.new(
      name: runtime_agent_name || agent_name,
      instructions: ->(context) { agent_instructions(context, runtime_configuration: runtime_configuration) },
      tools: agent_tools,
      model: agent_model,
      temperature: temperature.presence&.to_f || DEFAULT_TEMPERATURE,
      response_schema: response_schema || agent_response_schema
    )
  end

  def agent_instructions(context = nil, prompt_template: template_name, runtime_configuration: nil)
    enhanced_context = runtime_prompt_context(prompt_context, runtime_configuration)
    enhanced_context = enhanced_context.merge(context_state_context(context)) if context

    Captain::PromptRenderer.render(prompt_template, enhanced_context.with_indifferent_access)
  end

  def agent_model
    route = Llm::FeatureRouter.resolve(feature: 'assistant', account: account)
    return route[:model] if route[:source] == :account_override || account&.feature_enabled?('captain_integration_v2')

    installation_model.presence || route[:model]
  end

  private

  def runtime_prompt_context(context, runtime_configuration)
    return context unless runtime_configuration

    runtime_configuration.prompt_context_for(self, context)
  end

  def context_state_context(context)
    state = context.context[:state] || {}
    config = state[:assistant_config] || {}
    attrs = {
      current_time: format_current_time(state[:timezone]),
      conversation: state[:conversation] || {},
      contact: config['feature_contact_attributes'].present? ? state[:contact] : nil,
      campaign: state[:campaign] || {},
      message_length_limit: state[:message_length_limit],
      ownership_instruction: state[:ownership_instruction],
      suggested_replies_enabled: state[:suggested_replies_enabled],
      max_suggested_replies: state[:max_suggested_replies],
      product_cards_enabled: state[:product_cards_enabled]
    }
    attrs[:commerce_enabled] = state[:commerce_enabled] if state.key?(:commerce_enabled)
    attrs
  end

  def agent_name
    raise NotImplementedError, "#{self.class} must implement agent_name"
  end

  def template_name
    self.class.name.demodulize.underscore
  end

  def agent_tools
    []  # Default implementation, override if needed
  end

  def installation_model
    InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value
  end

  def agent_response_schema(suggested_replies: false, max_suggested_replies: 3, product_cards: false)
    Captain::ResponseSchema.for(
      suggested_replies: suggested_replies,
      max_suggested_replies: max_suggested_replies,
      product_cards: product_cards
    )
  end

  def format_current_time(timezone)
    tz = ActiveSupport::TimeZone[timezone] if timezone.present?
    time = tz ? Time.current.in_time_zone(tz) : Time.current
    time.strftime('%A, %B %d, %Y %I:%M %p %Z')
  end

  def prompt_context
    raise NotImplementedError, "#{self.class} must implement prompt_context"
  end
end

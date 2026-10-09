class Captain::Playground::Runner
  def initialize(assistant:, configuration_params:, message_history:)
    @assistant = assistant
    @configuration_params = configuration_params
    @message_history = message_history
  end

  def generate_response
    configuration = Captain::Playground::Configuration.new(
      assistant: @assistant,
      params: @configuration_params
    )
    run_details = Captain::Playground::RunDetails.new(configuration: configuration)
    runner = agent_runner(configuration, run_details)
    response = runner.generate_response(message_history: @message_history)
    details = run_details.to_h(agent_name: response['agent_name'])
    response.merge(run_details: details).merge(customer_view(response, runner.last_run_result, details))
  end

  private

  def customer_view(response, run_result, details)
    return {} if response['error']

    Captain::Playground::CustomerView.new(
      assistant: @assistant, response: response, run_result: run_result, message_history: @message_history,
      handoff_reason: handoff_reason(details)
    ).to_h
  end

  def handoff_reason(details)
    tool_name = Captain::Tools::HandoffTool.new(@assistant).name.split('--').last
    event = details[:events].find { |candidate| candidate[:type] == 'tool' && candidate[:name] == tool_name }
    event&.dig(:arguments)&.with_indifferent_access&.dig(:reason).presence
  end

  def agent_runner(configuration, run_details)
    run_options = Captain::Assistant::AgentRunnerService::RunOptions.new(
      callbacks: run_details.callbacks,
      source: 'playground',
      runtime_configuration: configuration
    )
    Captain::Assistant::AgentRunnerService.new(
      assistant: @assistant,
      run_options: run_options
    )
  end
end

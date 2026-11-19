module Captain::Assistant::RunnerCallbacksHelper
  private

  def prevent_scenario_reentry(runner)
    runner.on_chat_created do |chat, agent_name, _model, run_context|
      visited = run_context.context[:captain_visited_scenarios] ||= []
      # RubyLLM rebuilds the tool list at each hop. Remove only scenario tools already used in this run.
      visited.each { |tool_name| chat.tools.delete(tool_name) }
      if agent_name.start_with?("#{Captain::Scenario::HANDOFF_KEY_PREFIX}_")
        name = Agents::Helpers::NameNormalizer.to_tool_name(agent_name)
        visited << "#{Captain::Scenario::HANDOFF_TOOL_PREFIX}#{name}".to_sym
      end
    end
  end

  def add_callbacks_to_runner(runner)
    runner = add_agent_thinking_callback(runner) if @callbacks[:on_agent_thinking]
    runner = add_tool_start_callback(runner) if @callbacks[:on_tool_start]
    runner = add_tool_complete_callback(runner) if @callbacks[:on_tool_complete]
    runner = add_agent_handoff_callback(runner) if @callbacks[:on_agent_handoff]
    runner
  end

  def register_trace_input_callback(runner)
    runner.on_agent_thinking do |_agent_name, _input, context_wrapper|
      tracing = context_wrapper&.context&.dig(:__otel_tracing)
      next unless tracing

      trace_input = context_wrapper.context[:captain_v2_trace_current_input]
      tracing[:pending_llm_input] = trace_input if trace_input.present?
    end
  end

  def add_agent_thinking_callback(runner)
    runner.on_agent_thinking do |*args|
      @callbacks[:on_agent_thinking].call(*args)
    rescue StandardError => e
      Rails.logger.warn "[Captain] Callback error for agent_thinking: #{e.message}"
    end
  end

  def add_tool_start_callback(runner)
    runner.on_tool_start do |*args|
      @callbacks[:on_tool_start].call(*args)
    rescue StandardError => e
      Rails.logger.warn "[Captain] Callback error for tool_start: #{e.message}"
    end
  end

  def add_tool_complete_callback(runner)
    runner.on_tool_complete do |*args|
      @callbacks[:on_tool_complete].call(*args)
    rescue StandardError => e
      Rails.logger.warn "[Captain] Callback error for tool_complete: #{e.message}"
    end
  end

  def add_agent_handoff_callback(runner)
    runner.on_agent_handoff do |*args|
      @callbacks[:on_agent_handoff].call(*args)
    rescue StandardError => e
      Rails.logger.warn "[Captain] Callback error for agent_handoff: #{e.message}"
    end
  end
end

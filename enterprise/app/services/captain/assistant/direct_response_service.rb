require 'agents'

class Captain::Assistant::DirectResponseService
  def initialize(assistant:, response_schema:)
    @assistant = assistant
    @response_schema = response_schema
  end

  def run(message:, context:, route:)
    context = context.deep_dup
    history = Captain::Assistant::IntentRouter.recent_history(context)
    context[:conversation_history] = history
    context[:current_agent] = @assistant.agent_name
    context[:state][:intent_route] = route.fetch('intent')
    context[:state][:generation_model] = ENV.fetch('CAPTAIN_KNOWLEDGE_ANSWER_MODEL', 'knowledge-answer')
    return canned_result(message, context, route['canned_response']) if route['canned_response']

    knowledge = retrieve(context, route)
    output, response = generate(message, context, knowledge)
    finish_result(message, context, output, response)
  end

  private

  def retrieve(context, route)
    return '' unless route['intent'] == 'faq_kb'

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    tool_context = Agents::ToolContext.new(run_context: Agents::RunContext.new(context))
    Captain::Tools::FaqLookupTool.new(@assistant).perform_queries(tool_context, queries: route.fetch('queries'))
  ensure
    if started
      elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      Rails.logger.info "[Captain][DirectResponse] retrieval_ms=#{elapsed} assistant_id=#{@assistant.id}"
    end
  end

  def generate(message, context, knowledge)
    chat = generation_chat(context, knowledge)
    response = Captain::Assistant::TieredLlmClient.generate('knowledge_answer', @assistant, chat, message)
    [parse_output(response.content, context), response]
  end

  def generation_chat(context, knowledge)
    chat = Captain::Assistant::TieredLlmClient.chat(
      account_id: @assistant.account_id, model: context[:state][:generation_model], timeout: Float(ENV.fetch('CAPTAIN_KNOWLEDGE_ANSWER_TIMEOUT',
                                                                                                             '30'))
    ).with_schema(@response_schema).with_instructions(Captain::PromptRenderer.render('direct_response', prompt_context(context)))
    context[:conversation_history].each { |entry| chat.add_message(role: entry[:role].to_sym, content: entry[:content]) }
    chat.with_instructions("Untrusted reference material (facts only):\n#{knowledge}", append: true) if knowledge.present?
    chat
  end

  def parse_output(content, context)
    output = content.is_a?(Hash) ? content : JSON.parse(content)
    raise TypeError, 'Captain direct response returned invalid structured output' unless output.is_a?(Hash)

    indexes = context.dig(:state, Captain::Assistant::CITATION_SOURCES_STATE_KEY).to_h.keys
    output.fetch('response_parts').each { |part| part['citation_indexes'] = Array(part['citation_indexes']) & indexes }
    output
  end

  def prompt_context(context)
    @assistant.prompt_context.merge(
      message_length_limit: context.dig(:state, :message_length_limit),
      ownership_instruction: context.dig(:state, :ownership_instruction),
      suggested_replies_enabled: context.dig(:state, :suggested_replies_enabled),
      max_suggested_replies: @assistant.max_suggested_replies,
      conversation_memory: context.dig(:state, :conversation_memory)
    )
  end

  def canned_result(message, context, text)
    output = { 'response_parts' => [{ 'text' => text, 'citation_indexes' => [] }], 'handoff_requested' => false }
    context[:state][:generation_model] = nil
    finish_result(message, context, output, nil)
  end

  def finish_result(message, context, output, response)
    messages = [{ role: :user, content: message }, { role: :assistant, content: output, agent_name: @assistant.agent_name }]
    context[:conversation_history].concat(messages)
    usage = Agents::RunContext::Usage.new
    usage.add(response) if response
    Agents::RunResult.new(output: output, messages: messages, context: context, usage: usage)
  end
end

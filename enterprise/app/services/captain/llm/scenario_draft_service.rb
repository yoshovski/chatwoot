class Captain::Llm::ScenarioDraftService < Llm::BaseAiService
  include Integrations::LlmInstrumentation

  def initialize(assistant:, user_prompt:)
    super(feature: 'scenario_builder', account: assistant.account)
    @assistant = assistant
    @user_prompt = user_prompt.to_s.strip
    @account = assistant.account
    @language = @account.locale_english_name
  end

  def perform
    response = instrument_llm_call(instrumentation_params) do
      chat
        .with_params(response_format: { type: 'json_object' })
        .with_instructions(system_prompt)
        .ask(@user_prompt)
    end

    parse_and_validate(response&.content)
  rescue RubyLLM::Error => e
    Rails.logger.error "LLM API Error in ScenarioDraftService: #{e.message}"
    nil
  end

  private

  def available_tools
    @assistant.available_agent_tools.map do |tool|
      {
        'id' => tool[:id].to_s,
        'title' => tool[:title].to_s,
        'description' => tool[:description].to_s
      }
    end
  end

  def available_tool_ids
    @available_tool_ids ||= available_tools.pluck('id')
  end

  def system_prompt
    Captain::PromptRenderer.render(
      'scenario_builder',
      tools: available_tools,
      user_prompt: @user_prompt,
      language: @language
    )
  end

  def instrumentation_params
    {
      span_name: 'llm.captain.scenario_builder',
      model: @model,
      temperature: @temperature,
      feature_name: 'scenario_builder',
      account_id: @account.id,
      messages: [
        { role: 'system', content: system_prompt },
        { role: 'user', content: @user_prompt }
      ],
      metadata: { assistant_id: @assistant.id }
    }
  end

  def parse_and_validate(content)
    return nil if content.blank?

    parsed = JSON.parse(sanitize_json_response(content))
    return nil unless parsed.is_a?(Hash)

    build_draft_payload(parsed)
  rescue JSON::ParserError => e
    Rails.logger.error "JSON parse error in ScenarioDraftService: #{e.message}"
    nil
  end

  def build_draft_payload(parsed)
    title = parsed['title'].to_s.strip.truncate(60, omission: '')
    description = parsed['description'].to_s.strip.truncate(500, omission: '')
    raw_instruction = parsed['instruction'].to_s.strip
    return nil if title.blank? || description.blank? || raw_instruction.blank?

    cleaned_instruction = sanitize_tool_links(raw_instruction)
    tools = cleaned_instruction.scan(Concerns::CaptainToolsHelpers::TOOL_REFERENCE_REGEX).flatten.uniq

    {
      title: title,
      description: description,
      instruction: cleaned_instruction,
      tools: tools,
      notes: extract_notes(parsed['notes'])
    }
  end

  def sanitize_tool_links(instruction)
    instruction.gsub(%r{\[([^\]]+)\]\(tool://([^/)]+)\)}) do |match|
      tool_title = Regexp.last_match(1)
      tool_id = Regexp.last_match(2)
      available_tool_ids.include?(tool_id) ? match : tool_title
    end
  end

  def extract_notes(notes)
    Array(notes).map(&:to_s).reject(&:blank?).first(2)
  end
end

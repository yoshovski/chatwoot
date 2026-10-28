require 'agents'

class Captain::Tools::HttpTool < Captain::Tools::BasePublicTool
  REQUEST_FAILED = 'An error occurred while executing the request'.freeze
  NOT_FOUND = 'No matching record was found. Ask the customer to check the details they gave.'.freeze
  VERIFICATION_FAILED = "The details the customer gave don't match. Ask them to check them. Don't reveal anything about the record.".freeze
  CHECK_MESSAGE = "The check didn't pass. Tell the customer exactly this, and nothing else about the record: %<message>s".freeze
  TOO_MANY_FAILED_CHECKS = 'Too many failed checks; hand the conversation to a human.'.freeze
  CONFIRMATION_SHOWN = "A confirmation card was shown to the customer. Don't say the action is done.".freeze
  CONFIRMATION_UNAVAILABLE = "This action needs the customer to confirm with a button, which this channel doesn't have. " \
                             "Don't run it here; offer to hand the conversation to a human.".freeze
  MAX_VERIFICATION_FAILURES = 3
  VERIFICATION_FAILURE_TTL = 1.hour

  def initialize(assistant, custom_tool)
    @custom_tool = custom_tool
    super(assistant)
  end

  def active?
    @custom_tool.enabled?
  end

  # The AI gets the outputs it may see (or the raw response when the action saves none). On a failed step it gets a
  # short message and never data from the response, so a failed check reveals nothing about the record.
  def perform(tool_context, **params)
    state = tool_context&.state || {}
    return failure_result(TOO_MANY_FAILED_CHECKS, state) if verification_failures(state) >= MAX_VERIFICATION_FAILURES
    return request_confirmation(state, params) if @custom_tool.confirm?

    result = run_steps(state, params)
    return ai_response(result) if result.ok?

    step_failure(result, state)
  rescue StandardError => e
    Rails.logger.error("HttpTool execution error for #{@custom_tool.slug}: #{e.class} - #{e.message}")
    failure_result(REQUEST_FAILED, tool_context&.state)
  end

  def available_in_reply_suggestion?
    @custom_tool.read_only_action?
  end

  private

  def run_steps(state, params, stop_after: nil)
    Captain::Tools::ActionRunner.new(@custom_tool, state: state).run(params: params, contact: contact_values(state), stop_after: stop_after)
  end

  def step_failure(result, state)
    log_failure(result)
    failure_result(failure_message(result, state), state)
  end

  # Confirm mode: run the steps before the first one that changes data, then leave the rest to the customer's click.
  def request_confirmation(state, params)
    confirmation = Captain::Tools::ActionConfirmation
    return failure_result(CONFIRMATION_UNAVAILABLE, state) unless confirmation.buttons_supported?(state)

    start_at = confirmation.steps_before_confirmation(@custom_tool)
    outputs = {}
    if start_at.positive?
      result = run_steps(state, params, stop_after: @custom_tool.steps[start_at - 1]['key'])
      return step_failure(result, state) unless result.ok?

      outputs = result.outputs
    end
    show_confirmation(state, params.to_h.stringify_keys, outputs, start_at)
  end

  def show_confirmation(state, params, outputs, start_at)
    conversation = find_conversation(state)
    nonce = if conversation
              Captain::Tools::ActionConfirmation.store!(conversation, tool: @custom_tool, params: params, outputs: outputs, start_at: start_at)
            else
              SecureRandom.hex(16)
            end
    content = Captain::Tools::ActionConfirmation.message(@custom_tool, 'confirm_prompt', params: params, outputs: outputs,
                                                                                         locale: @assistant.account.locale)
    state[Captain::Tools::ActionConfirmation::STATE_KEY] = { 'nonce' => nonce, 'content' => content }
    CONFIRMATION_SHOWN
  end

  def safe_to_run_after_new_customer_message?
    @custom_tool.read_only_action?
  end

  def ai_response(result)
    return @custom_tool.format_response(result.last_request_body) if @custom_tool.outputs.empty?

    visible_keys = @custom_tool.outputs.select { |output| output['available_to_ai'] }.pluck('key')
    visible = result.outputs.slice(*visible_keys)
    return visible.to_json if @custom_tool.response_template.blank?

    response_data = @custom_tool.send(:parse_response_body, result.last_request_body)
    @custom_tool.send(:render_template, @custom_tool.response_template,
                      { 'outputs' => result.outputs, 'response' => response_data, 'r' => response_data })
  end

  def failure_message(result, state)
    case result.error_kind
    when :verification_failed
      count_verification_failure(state)
      check_message = @custom_tool.failure_message_for(result.failed_step)
      check_message ? format(CHECK_MESSAGE, message: check_message) : VERIFICATION_FAILED
    when :not_found then NOT_FOUND
    else REQUEST_FAILED
    end
  end

  def verification_failures(state)
    key = verification_failures_key(state)
    key ? Redis::Alfred.get(key).to_i : 0
  end

  def count_verification_failure(state)
    key = verification_failures_key(state)
    return unless key

    Redis::Alfred.incr(key)
    Redis::Alfred.expire(key, VERIFICATION_FAILURE_TTL.to_i)
  end

  def verification_failures_key(state)
    conversation_id = state.dig(:conversation, :id)
    return if conversation_id.blank? || @custom_tool.id.blank?

    format(::Redis::Alfred::CAPTAIN_ACTION_VERIFY_FAILURES, conversation_id: conversation_id, tool_id: @custom_tool.id)
  end

  def log_failure(result)
    detail = result.step_results.last&.dig(:error)
    Rails.logger.error("HttpTool execution error for #{@custom_tool.slug}: #{result.error_kind} at #{result.failed_step} - #{detail}")
  end

  def contact_values(state)
    contact = state[:contact] || {}
    { email: contact[:email], phone_number: contact[:phone_number], name: contact[:name] || find_contact(state)&.name,
      verified: state.dig(:contact_inbox, :hmac_verified) == true }
  end
end

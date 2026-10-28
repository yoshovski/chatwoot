require 'agents'

class Captain::Tools::HttpTool < Captain::Tools::BasePublicTool
  def initialize(assistant, custom_tool)
    @custom_tool = custom_tool
    super(assistant)
  end

  def active?
    @custom_tool.enabled?
  end

  def perform(tool_context, **params)
    state = tool_context&.state || {}
    result = Captain::Tools::ActionRunner.new(@custom_tool, state: state).run(params: params, contact: contact_values(state))
    return @custom_tool.format_response(result.last_request_body) if result.ok?

    log_failure(result)
    failure_result('An error occurred while executing the request', state)
  rescue StandardError => e
    Rails.logger.error("HttpTool execution error for #{@custom_tool.slug}: #{e.class} - #{e.message}")
    failure_result('An error occurred while executing the request', tool_context&.state)
  end

  def available_in_reply_suggestion?
    @custom_tool.http_method == 'GET'
  end

  private

  def safe_to_run_after_new_customer_message?
    @custom_tool.http_method == 'GET'
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

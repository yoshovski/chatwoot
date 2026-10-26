class Captain::Tools::SaveLeadDetailsTool < Captain::Tools::BasePublicTool
  description 'Save a business lead after the customer agrees to follow-up. Never use for viewer or end-user support.'
  param :name, type: 'string', desc: 'Name provided by the customer'
  param :email, type: 'string', desc: 'Email provided by the customer'
  param :lead_type, type: 'string', desc: 'Exact configured lead type name'
  param :summary, type: 'string', desc: 'One to three sentences summarizing the business inquiry'
  param :fields_json, type: 'string', desc: 'JSON object of configured field keys and customer-provided string values; omit unknown values'

  def perform(tool_context, fields_json:, **details)
    return failure_result('Lead capture is disabled', tool_context.state) unless @assistant.leads_enabled?
    return 'Preview only: no lead saved or CRM request sent.' if tool_context.state&.dig(:source) == 'playground'

    contact = find_contact(tool_context.state)
    return failure_result('Contact not found', tool_context.state) unless contact

    save_and_deliver(tool_context, contact, details, fields_json)
  rescue JSON::ParserError, ArgumentError, ActiveRecord::RecordInvalid => e
    recover_failed_save(tool_context, details, fields_json, e)
  end

  private

  def save_and_deliver(tool_context, contact, details, fields_json)
    result = Captain::Leads::CaptureService.new(@assistant, contact).perform(
      **details.slice(:name, :email, :lead_type, :summary), fields: JSON.parse(fields_json)
    )
    conversation = find_conversation(tool_context.state)
    Captain::Leads::DeliveryService.new(@assistant, conversation).perform(lead_type: details[:lead_type], summary: details[:summary]) if conversation
    tool_context.state[:lead_summary_saved_this_run] = true
    result
  end

  def recover_failed_save(tool_context, details, fields_json, error)
    conversation = find_conversation(tool_context.state)
    return failure_result(error.message, tool_context.state) unless conversation

    Captain::Leads::FailureHandoffService.new(@assistant, conversation).perform(
      tool_context, details: details.slice(:name, :email, :lead_type, :summary).merge(fields: fields_json, error: error.class.name)
    )
  end
end

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

    Captain::Leads::CaptureService.new(@assistant, contact).perform(
      **details.slice(:name, :email, :lead_type, :summary), fields: JSON.parse(fields_json)
    )
  rescue JSON::ParserError, ArgumentError, ActiveRecord::RecordInvalid => e
    failure_result(e.message, tool_context.state)
  end
end

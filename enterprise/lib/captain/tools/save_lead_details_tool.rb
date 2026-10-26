class Captain::Tools::SaveLeadDetailsTool < Captain::Tools::BasePublicTool
  description 'Save a business lead after the customer agrees to follow-up. Never use for viewer or end-user support.'
  param :name, type: 'string', required: false, desc: 'Customer-provided name; omit when identity was already collected by the contact form'
  param :email, type: 'string', required: false, desc: 'Customer-provided email; omit when identity was already collected by the contact form'
  param :lead_type, type: 'string', desc: 'Exact configured lead type name'
  param :summary, type: 'string', desc: 'One to three sentences summarizing the business inquiry'
  param :fields_json, type: 'string', desc: 'JSON object of configured field keys and customer-provided string values; omit unknown values'

  def perform(tool_context, fields_json:, **details)
    return failure_result('Lead capture is disabled', tool_context.state) unless @assistant.leads_enabled?
    return 'Preview only: no lead saved or CRM request sent.' if tool_context.state&.dig(:source) == 'playground'

    contact = find_contact(tool_context.state)
    return failure_result('Contact not found', tool_context.state) unless contact

    save_and_deliver(tool_context, contact, details, fields_json)
  rescue JSON::ParserError, ArgumentError => e
    failure_result("No lead changes were saved. Correct the tool arguments; never invent identity or hand off for this: #{e.message}",
                   tool_context.state)
  rescue ActiveRecord::RecordInvalid => e
    recover_failed_save(tool_context, details, fields_json, e)
  end

  private

  def save_and_deliver(tool_context, contact, details, fields_json)
    conversation = find_conversation(tool_context.state)
    captured = Captain::Leads::CaptureState.new(@assistant, conversation).captured?
    identity = stored_identity(contact, details, captured)
    result = Captain::Leads::CaptureService.new(@assistant, contact).perform(
      **details.slice(:lead_type, :summary), **identity, fields: JSON.parse(fields_json)
    )
    if conversation
      Captain::Leads::DeliveryService.new(@assistant, conversation).perform(lead_type: details[:lead_type], summary: details[:summary],
                                                                            notify: !captured)
    end
    tool_context.state[:lead_summary_saved_this_run] = true
    captured ? 'Existing lead updated using its stored identity. Continue helping; do not restart intake or repeat the confirmation.' : result
  end

  def stored_identity(contact, details, captured)
    return { name: contact.name, email: contact.email } if captured

    stored_name = contact.name unless Captain::Conversation::ContactCaptureService.missing_name?(contact)
    { name: details[:name].presence || stored_name, email: details[:email].presence || contact.email }
  end

  def recover_failed_save(tool_context, details, fields_json, error)
    conversation = find_conversation(tool_context.state)
    return failure_result(error.message, tool_context.state) unless conversation

    Captain::Leads::FailureHandoffService.new(@assistant, conversation).perform(
      tool_context, details: details.slice(:name, :email, :lead_type, :summary).merge(fields: fields_json, error: error.class.name)
    )
  end
end

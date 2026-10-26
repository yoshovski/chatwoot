class Captain::Tools::RequestLeadFollowupTool < Captain::Tools::BasePublicTool
  description 'Start business email follow-up once the need is clear: reuse known contact details or offer a form. No live handoff.'
  param :lead_type, type: 'string', desc: 'Exact configured lead type name'
  param :summary, type: 'string', desc: 'One to three sentences summarizing the business inquiry'
  param :fields_json, type: 'string', desc: 'Known configured field keys and customer-provided values as a JSON object'

  def perform(tool_context, lead_type:, summary:, fields_json:)
    return failure_result('Lead capture is disabled', tool_context.state) unless @assistant.leads_enabled?
    return typed_identity_instruction unless web_chat?(tool_context)

    conversation = find_conversation(tool_context.state)
    instruction = prepare_followup(tool_context, conversation, lead_type, summary, fields_json)
    return instruction if instruction

    form_instruction(tool_context)
  rescue JSON::ParserError, ArgumentError => e
    failure_result("No form was shown. Correct the tool arguments and continue helping: #{e.message}", tool_context.state)
  rescue ActiveRecord::RecordInvalid => e
    Captain::Leads::FailureHandoffService.new(@assistant, conversation).perform(
      tool_context, details: { summary: summary, fields: fields_json, error: e.class.name }
    )
  end

  private

  def prepare_followup(tool_context, conversation, lead_type, summary, fields_json)
    return failure_result('Conversation not found', tool_context.state) unless conversation || preview?(tool_context)
    if Captain::Leads::CaptureState.new(@assistant, conversation).captured?
      return 'Email follow-up is already captured. Do not show another form or restart intake. Continue helping with the current question.'
    end
    if Captain::Leads::FollowupFormService.new(@assistant, conversation).pending?
      return 'The follow-up form is already waiting for submission. Do not show another form, save a lead or repeat the invitation. Continue helping.'
    end
    return not_ready_instruction unless Captain::Leads::FollowupReadiness.new(@assistant, tool_context).ready?
    return if preview?(tool_context)

    start_followup(tool_context, conversation, lead_type, summary, fields_json)
  end

  def captured_instruction(tool_context)
    tool_context.state[:lead_summary_saved_this_run] = true
    tool_context.state[:lead_intake] = { captured: true, identity_available: true, form_pending: false }
    'Email follow-up is saved using existing contact details. Briefly acknowledge the business inquiry for email follow-up. ' \
      'Do not show a form, ask for identity or permission, or ask another qualification question. ' \
      'Do not claim an email, CRM sync or sales alert was delivered.'
  end

  def not_ready_instruction
    'No form was shown or lead saved. Establish a genuine business need with one useful qualification question, within the remaining allowance. ' \
      'If the visitor refused contact or this is end-user support, respect that and keep helping. Do not ask for permission to show a form ' \
      'or hand off because this tool request was declined.'
  end

  def form_instruction(tool_context)
    tool_context.state[:lead_followup_form_requested] = true
    'The optional email follow-up form will appear after your reply. Give one short, benefit-led invitation tailored to the business need. ' \
      'Do not ask whether the team may contact them or ask another qualification question. Do not ask for name/email in prose. ' \
      'No lead has been saved or follow-up requested yet: only submitting the form does that. No live handoff has happened.'
  end

  def preview?(tool_context) = tool_context.state[:source] == 'playground'

  def web_chat?(tool_context) = tool_context.state[:channel_type].in?([nil, 'Channel::WebWidget'])

  def start_followup(tool_context, conversation, lead_type, summary, fields_json)
    if newer_customer_message_arrived?(tool_context.state)
      return failure_result('Tool skipped because a newer customer message arrived', tool_context.state)
    end

    Captain::Leads::FollowupCaptureService.new(conversation, @assistant).stage!(
      lead_type: lead_type, summary: summary, fields: JSON.parse(fields_json)
    )
    captured_instruction(tool_context) if conversation.reload.additional_attributes['business_lead_captured']
  end

  def typed_identity_instruction
    'This channel has no contact form. Ask only for missing name and email, then call save_lead_details after consent.'
  end
end

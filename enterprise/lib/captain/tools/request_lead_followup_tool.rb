class Captain::Tools::RequestLeadFollowupTool < Captain::Tools::BasePublicTool
  description 'After a business agrees to email follow-up, show a contact form without handing off the live chat.'
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
    return consent_required_instruction unless Captain::Leads::FollowupConsent.new(@assistant, tool_context).granted?
    return if preview?(tool_context)

    stage_followup(conversation, lead_type, summary, fields_json)
    return unless conversation.reload.additional_attributes['business_lead_captured']

    tool_context.state[:lead_summary_saved_this_run] = true
    'Lead details saved. Confirm receipt in one short sentence.'
  end

  def consent_required_instruction
    'No form was shown or lead saved: the visitor has not requested or agreed to email follow-up. ' \
      'Continue answering or ask one useful qualification question and wait. Offer follow-up separately when useful. ' \
      'Do not mention a contact form, claim consent, or hand off just because this request was declined.'
  end

  def form_instruction(tool_context)
    tool_context.state[:lead_followup_form_requested] = true
    'The email follow-up contact form will appear after your reply. Briefly invite the visitor to complete it. ' \
      'Do not ask them to type name or email in chat. No live handoff has happened; continue helping normally.'
  end

  def preview?(tool_context) = tool_context.state[:source] == 'playground'

  def web_chat?(tool_context) = tool_context.state[:channel_type].in?([nil, 'Channel::WebWidget'])

  def stage_followup(conversation, lead_type, summary, fields_json)
    Captain::Leads::FollowupCaptureService.new(conversation, @assistant).stage!(
      lead_type: lead_type, summary: summary, fields: JSON.parse(fields_json)
    )
  end

  def typed_identity_instruction
    'This channel has no contact form. Ask only for missing name and email, then call save_lead_details after consent.'
  end
end

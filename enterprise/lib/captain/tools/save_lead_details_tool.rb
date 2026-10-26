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

    result = Captain::Leads::CaptureService.new(@assistant, contact).perform(
      **details.slice(:name, :email, :lead_type, :summary), fields: JSON.parse(fields_json)
    )
    deliver_lead(find_conversation(tool_context.state), lead_type: details[:lead_type], summary: details[:summary])
    result
  rescue JSON::ParserError, ArgumentError, ActiveRecord::RecordInvalid => e
    failure_result(e.message, tool_context.state)
  end

  private

  def deliver_lead(conversation, lead_type: nil, summary: nil)
    return unless conversation

    conversation.with_lock do
      create_private_summary_note(conversation, summary)
      apply_lead_labels(conversation, lead_type)
      attributes = conversation.additional_attributes.except('business_handoff').merge('business_lead_captured' => true)
      conversation.update!(additional_attributes: attributes)
    end
    return unless @assistant.config['lead_notification_team_id']

    Captain::Leads::NotifyTeamJob.perform_later(@assistant.id, conversation.id)
  end

  def create_private_summary_note(conversation, summary)
    content = summary.to_s.strip
    return if content.blank?
    return if conversation.messages.exists?(private: true, content: content)

    conversation.messages.create!(
      account: @assistant.account,
      inbox: conversation.inbox,
      sender: @assistant,
      message_type: :outgoing,
      private: true,
      content: content
    )
  end

  def apply_lead_labels(conversation, lead_type)
    return if lead_type.blank?

    type_key = lead_type.to_s.tr('_', '-')
    labels = ['prospect', type_key, type_key.downcase].uniq
    matching_labels = @assistant.account.labels.where(title: labels).pluck(:title)
    conversation.add_labels(matching_labels) if matching_labels.present?
  end
end

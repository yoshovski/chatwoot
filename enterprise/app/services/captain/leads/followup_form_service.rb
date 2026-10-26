class Captain::Leads::FollowupFormService
  def initialize(assistant, conversation)
    @assistant = assistant
    @conversation = conversation
  end

  def payload
    contact = @conversation&.contact
    missing = []
    missing << 'name' if Captain::Conversation::ContactCaptureService.missing_name?(contact)
    missing << 'email' if contact&.email.blank?
    form = Captain::Conversation::ContactCaptureService.form_payload(missing, assistant: @assistant)
    form.merge(content: I18n.t('captain.leads.followup_form'),
               content_attributes: form[:content_attributes].merge('purpose' => 'business_followup'),
               additional_attributes: { agent_name: @assistant.agent_name })
  end

  def perform(message, submitted)
    message.with_lock do
      return false if message.content_attributes.to_h.values_at('contact_details_saved', 'followup_needs_review').include?(true)

      values = submitted.to_h { |item| [item['name'], item['value']] }
      Captain::Leads::FollowupCaptureService.new(@conversation, @assistant).complete!(**values.slice('name', 'email').symbolize_keys)
      return false unless @conversation.reload.additional_attributes['business_lead_captured']

      message.update!(content_attributes: message.content_attributes.merge('contact_details_saved' => true))
    end
    post_reply(I18n.t('captain.leads.followup_saved'))
    true
  rescue ActiveRecord::RecordInvalid, ArgumentError => e
    recover(message, submitted, e)
  end

  private

  def recover(message, submitted, error)
    state = { conversation: { id: @conversation.id }, contact: { id: @conversation.contact_id } }
    context = Agents::ToolContext.new(run_context: Agents::RunContext.new({ state: state }))
    details = Captain::Leads::FollowupCaptureService.new(@conversation, @assistant).pending_details
    Captain::Leads::FailureHandoffService.new(@assistant, @conversation).perform(
      context, details: details.merge(submitted: submitted, error: error.class.name)
    )
    message.update!(content_attributes: message.content_attributes.merge('followup_needs_review' => true))
    policy = Captain::Conversation::HandoffPolicy.new(assistant: @assistant, conversation: @conversation)
    post_reply(state[:lead_failure_handoff] ? policy.handoff_message : policy.keep_message)
    true
  end

  def post_reply(content)
    @conversation.messages.create!(message_type: :outgoing, account_id: @conversation.account_id, inbox_id: @conversation.inbox_id,
                                   sender: @assistant, content: content, preserve_waiting_since: true,
                                   additional_attributes: { 'agent_name' => @assistant.agent_name })
  end
end

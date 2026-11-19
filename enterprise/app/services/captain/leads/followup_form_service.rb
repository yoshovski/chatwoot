class Captain::Leads::FollowupFormService
  CUSTOM_COPY_FIELDS = { 'form' => 'lead_form_message', 'submit' => 'lead_form_submit' }.freeze

  def initialize(assistant, conversation)
    @assistant = assistant
    @conversation = conversation
  end

  def payload(customer_message: nil, locale: nil)
    contact = @conversation&.contact
    missing = []
    missing << 'name' if Captain::Conversation::ContactCaptureService.missing_name?(contact)
    missing << 'email' if contact&.email.blank?
    locale ||= Captain::Conversation::CustomerLocale.resolve(conversation: @conversation, assistant: @assistant, customer_message: customer_message)
    form = Captain::Conversation::ContactCaptureService.form_payload(missing, locale: locale, assistant: @assistant)
    form.merge(content: followup_copy('form', locale),
               content_attributes: form[:content_attributes].merge('purpose' => 'business_followup',
                                                                   'button_label' => followup_copy('submit', locale)),
               additional_attributes: { agent_name: @assistant.agent_name })
  end

  def pending?
    return false unless @conversation

    capture = Captain::Conversation::ContactCaptureService.new(conversation: @conversation, assistant: @assistant)
    return false if capture.unsubmitted_turns_count >= 4

    @conversation.messages.where(content_type: :form, created_at: Captain::Conversation::ContactCaptureService::GUARD_TTL.seconds.ago..)
                 .any? { |message| message.content_attributes['purpose'] == 'business_followup' && capture.form_active?(message) }
  end

  def perform(message, submitted)
    message.with_lock do
      return false if message.content_attributes.to_h.values_at('contact_details_saved', 'followup_needs_review').include?(true)

      values = submitted.to_h { |item| [item['name'], item['value']] }
      Captain::Leads::FollowupCaptureService.new(@conversation, @assistant).complete!(**values.slice('name', 'email').symbolize_keys)
      return false unless @conversation.reload.additional_attributes['business_lead_captured']

      message.update!(content_attributes: message.content_attributes.merge('contact_details_saved' => true))
    end
    acknowledge(message)
    true
  rescue ActiveRecord::RecordInvalid, ArgumentError => e
    recover(message, submitted, e)
  end

  private

  def followup_copy(key, locale, **)
    field = CUSTOM_COPY_FIELDS[key]
    text = Captain::LocalizedMessages.new(@assistant.config).text(field, locale) if field
    text || Captain::Conversation::CustomerLocale.translate("captain.leads.followup_#{key}", locale: locale, assistant: @assistant, **)
  end

  def acknowledge(message)
    locale = message.content_attributes[Captain::Conversation::ContactCaptureService::LOCALE_KEY] || I18n.locale
    post_reply(followup_copy('saved', locale, name: @conversation.contact.name))
  end

  def recover(message, submitted, error)
    state = { conversation: { id: @conversation.id }, contact: { id: @conversation.contact_id } }
    context = Agents::ToolContext.new(run_context: Agents::RunContext.new({ state: state }))
    details = Captain::Leads::FollowupCaptureService.new(@conversation, @assistant).pending_details
    Captain::Leads::FailureHandoffService.new(@assistant, @conversation).perform(
      context, details: details.merge(submitted: submitted, error: error.class.name)
    )
    message.update!(content_attributes: message.content_attributes.merge('followup_needs_review' => true))
    locale = message.content_attributes[Captain::Conversation::ContactCaptureService::LOCALE_KEY]
    policy = Captain::Conversation::HandoffPolicy.new(assistant: @assistant, conversation: @conversation, locale: locale)
    post_reply(state[:lead_failure_handoff] ? policy.handoff_message : policy.keep_message)
    true
  end

  def post_reply(content)
    @conversation.messages.create!(message_type: :outgoing, account_id: @conversation.account_id, inbox_id: @conversation.inbox_id,
                                   sender: @assistant, content: content, preserve_waiting_since: true,
                                   additional_attributes: { 'agent_name' => @assistant.agent_name })
  end
end

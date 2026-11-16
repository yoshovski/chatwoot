module Enterprise::Widget::AttentionService
  INTENTS = { 'question' => 'awaiting_answer', 'check_in' => 'answer_complete' }.freeze

  # The assistant writes the check-in for this conversation. It runs after the claim, outside the locks; when the model
  # fails the widget shows its fixed line and the reply's own buttons.
  def perform(kind:, message_id: nil, event_id: nil)
    grant = super
    return grant unless grant && grant[:kind] == 'check_in'

    grant.merge(check_in_content)
  end

  private

  def check_in_content
    assistant = @conversation.inbox.captain_assistant
    content = Captain::Conversation::CheckInService.new(conversation: @conversation, assistant: assistant, widget: true).generated
    return {} unless content

    suggestions = Array(content[:suggested_replies]).filter_map do |reply|
      title = reply['label'].to_s.strip
      { title: title, value: reply['message'].to_s.strip.presence || title } if title.present?
    end
    { text: content[:text], suggestions: suggestions.first(Captain::Conversation::CheckInService::WIDGET_MAX_SUGGESTIONS) }
  rescue StandardError => e
    # The check-in is already claimed; any failure here must still let the widget show its fixed line.
    Rails.logger.warn "[Widget][Attention] check-in text fallback conversation=#{@conversation.id} error=#{e.class.name}"
    {}
  end

  def assistant_eligible?(kind)
    assistant = @conversation.inbox.captain_assistant
    return false unless assistant && @message.sender == assistant && attention_enabled?(assistant)
    return false unless @message.additional_attributes['captain_attention_intent'] == INTENTS.fetch(kind)
    return false unless @message.created_at <= attention_delay(assistant, kind).seconds.ago

    assistant_may_follow_up?(assistant)
  end

  def attention_enabled?(assistant)
    assistant.account.feature_enabled?('captain_integration_v2') && assistant.config['widget_attention_enabled'] != false
  end

  def attention_delay(assistant, kind)
    return Captain::Behaviour.widget_check_in_awaiting_seconds(assistant) if kind == 'question'

    Captain::Behaviour.widget_check_in_completed_seconds(assistant)
  end

  # Not while a human owns the conversation, a lead offer or form is due, or a follow-up is scheduled.
  def assistant_may_follow_up?(assistant)
    ownership = Captain::Conversation::OwnershipService.new(conversation: @conversation, assistant: assistant)
    state = Captain::Conversation::CheckInState.new(conversation: @conversation, assistant: assistant)
    ownership.may_reply? && !ownership.waiting? && state.assistant_spoke_last? && !state.lead_guard? &&
      !Captain::Leads::FollowupFormService.new(assistant, @conversation).pending? &&
      !@conversation.captain_scheduled_actions.pending.exists?
  end
end

class Captain::Conversation::ResponseBuilderJob < ApplicationJob # rubocop:disable Metrics/ClassLength
  include Captain::Conversation::V1ActionClassifier
  include Captain::Conversation::V1FalsePromiseHandler
  include Captain::Conversation::V2LifecycleEvents
  include Captain::Conversation::MessageBuilder
  include Captain::Conversation::ResponseLifecycleLogging

  MAX_MESSAGE_LENGTH = 10_000
  retry_on ActiveStorage::FileNotFoundError, attempts: 3, wait: 2.seconds
  retry_on Faraday::BadRequestError, attempts: 3, wait: 2.seconds

  def perform(conversation, assistant, responding_to_message_id = nil)
    @conversation = conversation
    @account = conversation.account
    @inbox = conversation.inbox
    @assistant = assistant
    @responding_to_message_id = responding_to_message_id if captain_v2_enabled?

    @conversation.reload
    return log_non_pending unless may_reply?

    start_reply

    return generate_and_process_response unless captain_v2_enabled?

    return log_pre_generation_discard if newer_customer_message_arrived?

    generate_response_with_v2
  rescue ActiveStorage::FileNotFoundError, Faraday::BadRequestError => e
    handle_error(e)
    raise e
  rescue StandardError => e
    handle_error(e)
  ensure
    toggle_typing(Events::Types::CONVERSATION_TYPING_OFF) if @typing
    Current.executed_by = nil
  end

  private

  def start_reply
    Current.executed_by = @assistant
    toggle_typing(Events::Types::CONVERSATION_TYPING_ON)
  end

  # Shows "typing" in the widget and the dashboard while Captain works, also when it
  # keeps answering after a handoff.
  def toggle_typing(event)
    @typing = event == Events::Types::CONVERSATION_TYPING_ON
    Conversations::TypingStatusManager.new(@conversation, @assistant, {}).trigger_typing_event(event, false)
  end

  def delegate_ownership_service
    Captain::Conversation::OwnershipService.new(
      conversation: @conversation,
      assistant: @assistant
    )
  end

  def may_reply?
    delegate_ownership_service.may_reply?
  end

  def account
    @account || @conversation.account
  end

  def inbox
    @inbox || @conversation.inbox
  end

  def generate_and_process_response
    message_history = collect_previous_messages
    @response = Captain::Llm::AssistantChatService.new(assistant: @assistant, conversation: @conversation).generate_response(
      message_history: message_history
    )
    classify_v1_response_action(message_history) if may_reply?
    repair_v1_false_promise_response(message_history) if may_reply?
    process_response
  end

  def generate_response_with_v2
    runner_service = v2_runner_service
    message_history = Captain::Conversation::MessageHistoryBuilderService.new(conversation: @conversation).perform
    @response = runner_service.generate_response(message_history: message_history)
    @run_result = runner_service.last_run_result

    @v2_handoff_tool_completed = runner_service.handoff_completed?
    @v2_response_discarded = runner_service.response_discarded?
    return process_response if v2_handoff_tool_completed?
    return if @v2_response_discarded || newer_customer_message_arrived?

    process_response
  end

  def v2_runner_service
    run_options = Captain::Assistant::AgentRunnerService::RunOptions.new(
      responding_to_message_id: @responding_to_message_id
    )
    Captain::Assistant::AgentRunnerService.new(assistant: @assistant, conversation: @conversation, run_options: run_options)
  end

  def process_response # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    # The V2 runner rescues its own generation errors and signals them via an error
    # response instead of raising, so the failure event must be emitted here — the
    # top-level handle_error path only sees exceptions raised outside the runner.
    record_v2_response_failure(@response['error_reason']) if v2_generation_errored?

    if v2_handoff_tool_fired?
      process_v2_handoff_response
    elsif v1_handoff_requested?
      delegate_ownership_service.waiting? ? process_v1_handoff_while_waiting : process_v1_handoff_request
    elsif v2_handoff_declared?
      process_v2_declared_handoff
    elsif v2_handoff_safety_net_triggered?
      process_v2_declared_handoff(source: Captain::ConversationEvents::Sources::SAFETY_NET)
    elsif v2_empty_response_handoff?
      process_v2_empty_response_handoff
    elsif may_reply?
      process_standard_response
    end
  end

  def process_v1_handoff_while_waiting
    trigger_handoff_contact_form
    # The handoff token (also what a failed V2 run returns) is internal. The
    # conversation is already waiting for a human, so post nothing for it.
    return if legacy_v1_handoff_token?

    process_standard_response
  end

  def process_v1_handoff_request
    # V1 only signals via the response string — no state has been touched yet. If
    # the conversation isn't pending anymore, a human took over mid-run; bail out
    # rather than posting a stale handoff message on top of their reply.
    return unless conversation_pending?

    process_v1_handoff
    record_v2_failure_handoff(source: Captain::ConversationEvents::Sources::GENERATION_FAILURE) if v2_generation_errored?
  end

  def process_standard_response
    @conversation.reload
    return unless may_reply?

    message = nil
    ActiveRecord::Base.transaction do
      next if captain_v2_enabled? && newer_customer_message_arrived?

      preserve_waiting = delegate_ownership_service.waiting?
      message = create_messages(preserve_waiting_since: preserve_waiting)
      Rails.logger.info("[CAPTAIN][ResponseBuilderJob] Incrementing response usage for #{account.id}")
      account.increment_response_usage
    end
    return unless message

    delegate_ownership_service.clear_returned_to_ai_flag!
    capture_assistant_session(result_message: message, credits_consumed: 1.0)
    record_v2_response_completed(message) if captain_v2_enabled?
    apply_v2_reply_labels(handed_off: false, answer: message.content)
  end

  def process_v2_handoff_response
    # Captain V1 infers completion from status. Captain V2 uses the completion
    # marker set inside the locked handoff.
    if captain_v2_enabled?
      return unless v2_handoff_tool_completed? || conversation_pending?

      v2_handoff_tool_completed? ? process_v2_handoff : process_v1_handoff
      record_v2_failure_handoff(source: Captain::ConversationEvents::Sources::TOOL) unless v2_handoff_tool_completed?
    else
      conversation_pending? ? process_v1_handoff : process_v2_handoff
    end

    capture_assistant_session(result_message: @handoff_message, credits_consumed: 0.0)
  end

  def v1_handoff_requested?
    legacy_v1_handoff_token? || classifier_v1_handoff_requested?
  end

  def classifier_v1_handoff_requested?
    @response['action'] == 'handoff'
  end

  def legacy_v1_handoff_token?
    @response['response'] == 'conversation_handoff'
  end

  def v2_handoff_tool_fired? = @response['handoff_tool_called']
  def v2_handoff_tool_completed? = @v2_handoff_tool_completed == true
  def v2_handoff_declared? = @response['handoff_requested'] == true

  def process_v1_handoff
    I18n.with_locale(@assistant.account.locale) do
      Rails.logger.info(
        "[CAPTAIN][ResponseBuilderJob] V1 handoff requested for account=#{account.id} conversation=#{@conversation.display_id} " \
        "source=#{@response&.dig('action_source') || 'legacy'} reason=#{@response&.dig('action_reason')}"
      )
      apply_handoff_extras
      create_handoff_message
      @conversation.bot_handoff!
      report_v1_handoff_not_executed if conversation_pending?
      send_out_of_office_message_if_applicable
      trigger_handoff_contact_form
      apply_v2_reply_labels(handed_off: true, answer: @handoff_message&.content) if captain_v2_enabled?
    end
  end

  def process_v2_handoff
    # HandoffTool already ran bot_handoff! + OOO inside the agent loop. Preserve
    # waiting_since so this message doesn't clear the timestamp it left in place.
    I18n.with_locale(@assistant.account.locale) do
      answer = create_messages(preserve_waiting_since: true) if deliverable_v2_handoff_answer?
      # A delivered answer already tells the customer a colleague will continue.
      @handoff_message = answer || create_handoff_message(preserve_waiting_since: true)
      trigger_handoff_contact_form
      apply_v2_reply_labels(handed_off: true, answer: @handoff_message&.content)
    end
  end

  # The agent declared a handoff in its answer but never called the handoff tool,
  # so the customer was promised a colleague nobody was told about. Deliver the
  # answer, then run the handoff the tool would have run. While a handoff is
  # already waiting for a human, the answer is all that is needed.
  def process_v2_declared_handoff(source: Captain::ConversationEvents::Sources::DECLARED, custom_message: nil)
    return process_standard_response unless conversation_pending?

    I18n.with_locale(@assistant.account.locale) do
      Rails.logger.info(
        "[CAPTAIN][ResponseBuilderJob] Handoff #{source} without the handoff tool for account=#{account.id} " \
        "conversation=#{@conversation.display_id}"
      )
      @handoff_message = if custom_message.present?
                           create_outgoing_message(custom_message, agent_name: @response&.dig('agent_name'))
                         else
                           create_messages
                         end
      apply_handoff_extras
      @conversation.bot_handoff!
      record_v2_declared_handoff(source: source)
      send_out_of_office_message_if_applicable
      trigger_handoff_contact_form
      apply_v2_reply_labels(handed_off: true, answer: @handoff_message&.content)
    end

    capture_assistant_session(result_message: @handoff_message, credits_consumed: 0.0)
  end

  def v2_empty_response_handoff?
    return false unless captain_v2_enabled?
    return false unless conversation_pending?
    return false unless v2_formatted_prose_blank?

    !v2_catalog_searches_empty? && !v2_customer_message_has_attachments? && !v2_model_returned_answer?
  end

  def process_v2_empty_response_handoff
    handoff_text = I18n.with_locale(@assistant.account.locale) do
      I18n.t('conversations.captain.empty_response_handoff')
    end
    process_v2_declared_handoff(custom_message: handoff_text)
  end

  def apply_v2_reply_labels(handed_off: false, answer: nil)
    return unless captain_v2_enabled? && @assistant.reply_labels?

    labels = Captain::Conversation::ReplyLabels.new(
      assistant: @assistant,
      customer_message: responding_to_customer_message,
      answer: v2_reply_answer_text(answer),
      products_shown: v2_products_shown?,
      handed_off: handed_off
    ).labels

    return if labels.empty?

    labels.each { |title| account.labels.find_or_create_by!(title: title) }
    @conversation.add_labels(labels)
  end

  def v2_reply_answer_text(answer)
    answer.presence || @handoff_message&.content.presence || Captain::Assistant::ResponseParts.from_response(@response).plain_text
  end

  def v2_products_shown?
    @assistant.shopify_catalog_tools_available? &&
      Captain::Conversation::ProductCardsBuilder.new(
        assistant: @assistant,
        conversation: @conversation,
        response: @response,
        run_result: @run_result
      ).products?
  end

  def v2_handoff_safety_net_triggered?
    return false unless captain_v2_enabled?
    return false unless @assistant.handoff_safety_net?
    return false unless conversation_pending?

    customer_msg = responding_to_customer_message
    answer_text = Captain::Assistant::ResponseParts.from_response(@response).plain_text
    Captain::Conversation::HandoffSafetyNet.new(
      assistant: @assistant,
      customer_message: customer_msg,
      answer: answer_text
    ).triggered?
  end

  def deliverable_v2_handoff_answer?
    return false if @v2_response_discarded || @response['error'] || legacy_v1_handoff_token? || newer_customer_message_arrived?

    @conversation.reload
    @conversation.open? && !delegate_ownership_service.human_taken_over? &&
      Captain::Assistant::ResponseParts.from_response(@response).plain_text.present?
  end

  def send_out_of_office_message_if_applicable
    # Campaign conversations should never receive OOO templates — the campaign itself
    # serves as the initial outreach, and OOO would be confusing in that context.
    return if @conversation.campaign.present?

    ::MessageTemplates::Template::OutOfOffice.perform_if_applicable(@conversation)
  end

  def create_handoff_message(preserve_waiting_since: false)
    @handoff_message = create_outgoing_message(
      @assistant.config['handoff_message'].presence || I18n.t('conversations.captain.handoff'),
      preserve_waiting_since: preserve_waiting_since
    )
  end

  # Capture runs outside the delivery transaction and never raises (the service
  # swallows its own failures): a session-logging bug must never roll back the
  # customer reply or trigger the top-level handle_error handoff on top of it.
  def capture_assistant_session(result_message:, credits_consumed:)
    Captain::Assistant::SessionCaptureService.new(assistant: @assistant, conversation: @conversation, run_result: @run_result,
                                                  result_message: result_message, credits_consumed: credits_consumed).capture
  end

  def handle_error(error)
    log_error(error)
    @response ||= {}
    @response['action_source'] ||= 'error'
    @response['action_reason'] ||= error_action_reason(error)
    record_v2_response_failure(error_action_reason(error)) if captain_v2_enabled?
    process_error_handoff
    true
  end

  def process_error_handoff
    return unless conversation_pending?
    return if captain_v2_enabled? && newer_customer_message_arrived?

    process_v1_handoff
    record_v2_failure_handoff(source: Captain::ConversationEvents::Sources::GENERATION_FAILURE) if captain_v2_enabled?
  end

  def log_error(error)
    ChatwootExceptionTracker.new(error, account: account).capture_exception
  end

  def error_action_reason(error)
    error.class.name.underscore.tr('/', '_')
  end

  def captain_v2_enabled?
    account.feature_enabled?('captain_integration_v2')
  end

  def report_v1_handoff_not_executed
    error = StandardError.new("Captain V1 handoff requested but conversation #{@conversation.display_id} is still pending")
    ChatwootExceptionTracker.new(error, account: account).capture_exception
    Rails.logger.error(
      "[CAPTAIN][ResponseBuilderJob] V1 handoff requested but not executed for account=#{account.id} " \
      "conversation=#{@conversation.display_id}"
    )
  end

  def newer_customer_message_arrived?
    return false if @responding_to_message_id.blank?

    Conversation.uncached do
      @conversation.messages
                   .captain_response_triggering
                   .exists?(['messages.id > ?', @responding_to_message_id])
    end
  end

  def apply_handoff_extras
    Captain::Conversation::HandoffService.new(
      conversation: @conversation,
      assistant: @assistant
    ).apply_extras!
  end

  def trigger_handoff_contact_form
    Captain::Conversation::HandoffService.new(
      conversation: @conversation,
      assistant: @assistant
    ).trigger_contact_capture_form!(triggering_message: responding_to_customer_message)
  end

  def responding_to_customer_message
    return @conversation.messages.where(id: @responding_to_message_id).first if @responding_to_message_id.present?

    @conversation.messages.incoming.last
  end
end

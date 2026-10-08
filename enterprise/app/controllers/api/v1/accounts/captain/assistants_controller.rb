class Api::V1::Accounts::Captain::AssistantsController < Api::V1::Accounts::BaseController # rubocop:disable Metrics/ClassLength
  before_action -> { check_authorization(Captain::Assistant) }

  before_action :set_assistant, only: [:show, :update, :destroy, :playground, :playground_run, :metrics, :faq_stats, :summary, :drilldown, :avatar]

  def index
    @assistants = account_assistants.ordered
  end

  def show; end

  def create
    @assistant = account_assistants.create!(assistant_params)
  end

  def update
    @assistant.with_lock do
      permitted_params = assistant_params
      permitted_params[:config] = @assistant.config.merge(permitted_params[:config].to_h) if permitted_params[:config]

      @assistant.update!(permitted_params)
    end
  end

  def destroy
    @assistant.destroy
    head :no_content
  end

  def avatar
    @assistant.avatar.purge if @assistant.avatar.attached?
    @assistant.reload
    render :show
  end

  def playground
    return enqueue_v2_playground_run if captain_v2_enabled?

    Captain::Playground::Configuration.reject_v1! if playground_configuration_supplied?
    render json: Captain::Llm::AssistantChatService.new(assistant: @assistant, source: 'playground').generate_response(
      additional_message: playground_params[:message_content],
      message_history: message_history
    )
  rescue Captain::Playground::Configuration::Invalid => e
    render json: { error: e.message, errors: e.errors }, status: :unprocessable_entity
  end

  def playground_run
    render json: Captain::PlaygroundRunJob.result(@assistant, params.require(:run_id)) || { status: 'pending' }
  end

  def tools
    assistant = Captain::Assistant.new(account: Current.account)
    @tools = assistant.available_agent_tools
  end

  def metrics
    render json: Captain::AssistantStatsBuilder.new(@assistant, params[:range], params[:timezone_offset]).metrics
  end

  def faq_stats
    builder = Captain::AssistantStatsBuilder.new(
      @assistant,
      suggestions_scope: Captain::FaqSuggestionFinder.new(Current.user, Current.account).perform
    )

    render json: builder.faq_stats
  end

  def summary
    window = Captain::AssistantStatsWindow.new(params[:range], params[:timezone_offset])
    result = cached_or_generated_summary(window, summary_stats)

    if result[:error]
      render json: { error: result[:error] }, status: :unprocessable_content
    else
      render json: { message: result[:message] }
    end
  end

  def drilldown
    return head :unprocessable_entity unless Captain::AssistantDrilldownBuilder.supported_metric?(params[:metric])

    render json: Captain::AssistantDrilldownBuilder.new(@assistant, drilldown_params).build
  end

  private

  def drilldown_params
    params.permit(:metric, :range, :timezone_offset, :page, :per_page)
  end

  def cached_or_generated_summary(window, stats)
    cache_key = summary_cache_key(window.range)
    cached = Rails.cache.read(cache_key)
    return cached if cached

    result = Captain::OverviewSummaryService.new(
      account: Current.account,
      assistant: @assistant,
      first_name: Current.user.name.to_s.split.first,
      stats: stats,
      period: window.period
    ).perform
    # Don't cache transient LLM/config failures, otherwise every reload returns 422 for the next hour.
    Rails.cache.write(cache_key, result, expires_in: 1.hour) unless result[:error]
    result
  end

  def summary_stats
    params.require(:stats).permit(
      conversations_handled: %i[current],
      hours_saved: %i[current],
      auto_resolution_rate: %i[current trend],
      handoff_rate: %i[current trend],
      reopen_rate: %i[current trend],
      knowledge: %i[coverage approved documents]
    ).to_h.deep_symbolize_keys
  end

  def summary_cache_key(range)
    "captain_overview_summary/#{@assistant.id}/#{Current.user.id}/#{range}/#{Date.current}"
  end

  def set_assistant
    @assistant = account_assistants.find(params[:id])
  end

  def account_assistants
    @account_assistants ||= Captain::Assistant.for_account(Current.account.id)
  end

  def assistant_config_attributes
    attributes = [
      :product_name, :feature_faq, :feature_memory, :feature_citation,
      :feature_contact_attributes, :welcome_message, :handoff_message,
      :resolution_message, :instructions, :temperature, :auto_resolve_mode,
      :response_window, :continue_while_waiting, :suggested_replies,
      :max_suggested_replies, :product_cards,
      { link_allowlist: [], image_allowlist: [] }
    ]
    if Current.account.feature_enabled?('captain_integration_v2')
      attributes += [
        :auto_resolve_after, :send_inactivity_resolution_message,
        :handoff_safety_net, { handoff_safety_net_keywords: [] },
        :reply_labels, :outcome_labels,
        :handoff_fallback_agent_id, :handoff_fallback_team_id
      ]
    end
    attributes
  end

  def assistant_params
    permitted = params.require(:assistant).permit(:name, :description, :avatar,
                                                  config: assistant_config_attributes)

    # Handle array parameters separately to allow partial updates
    permitted[:response_guidelines] = params[:assistant][:response_guidelines] if params[:assistant].key?(:response_guidelines)
    permitted[:guardrails] = params[:assistant][:guardrails] if params[:assistant].key?(:guardrails)

    permit_audience_config(permitted)
    permit_reply_label_keywords(permitted)

    permitted
  end

  # The audience is a recursive condition tree that strong params can't whitelist by shape;
  # pass it through raw and let Captain::AudienceValidator enforce validity.
  def permit_audience_config(permitted)
    config = params[:assistant][:config]
    return unless config.try(:key?, :audience)

    audience = config[:audience]
    permitted[:config][:audience] = audience.respond_to?(:permit!) ? audience.permit!.to_h : audience
  end

  def permit_reply_label_keywords(permitted)
    config = params[:assistant][:config]
    return unless config.try(:key?, :reply_label_keywords)

    keywords = config[:reply_label_keywords]
    permitted[:config][:reply_label_keywords] = keywords.respond_to?(:permit!) ? keywords.permit!.to_h : keywords
  end

  def playground_params
    params.require(:assistant).permit(
      :message_content,
      message_history: [:role, :content, :agent_name],
      playground_config: [
        :knowledge_text,
        { scenario_ids: [], response_guidelines: [], guardrails: [],
          temporary_scenarios: [:client_id, :title, :description, :instruction] }
      ]
    )
  end

  # Validates the configuration now so mistakes still return 422, then runs the message in the background.
  def enqueue_v2_playground_run
    configuration_params = playground_configuration_params
    if configuration_params
      Captain::Playground::Configuration.new(assistant: @assistant, params: configuration_params)
      configuration_params = configuration_params.to_unsafe_h
    end
    run_id = SecureRandom.uuid
    Captain::PlaygroundRunJob.perform_later(@assistant, run_id, configuration_params, playground_message_history)
    render json: { run_id: run_id }, status: :accepted
  end

  def playground_configuration_params
    return unless playground_configuration_supplied?

    params[:playground_config] || params[:assistant]&.[](:playground_config) ||
      raise(Captain::Playground::Configuration::Invalid, { 'playground_config' => ['must be an object'] })
  end

  def playground_configuration_supplied? = params.key?(:playground_config) || params[:assistant]&.key?(:playground_config)

  def message_history
    Array(playground_params[:message_history]).map do |message|
      {
        role: message[:role],
        content: message[:content],
        agent_name: message[:agent_name]
      }.compact
    end
  end

  def playground_message_history
    history = message_history
    current_message = playground_params[:message_content]
    return history if current_message.blank?

    current_user_message = { role: 'user', content: current_message }
    return history if history.last == current_user_message

    history + [current_user_message]
  end

  def captain_v2_enabled?
    @assistant.account.feature_enabled?('captain_integration_v2')
  end
end

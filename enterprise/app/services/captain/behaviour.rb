# How every Captain agent behaves. ChatOctave decides this; merchants only set content (knowledge, instructions, tone).
module Captain::Behaviour
  # Decides per conversation whether the visitor is a customer, a prospect or a shopper.
  ROLE = 'adaptive'.freeze
  # The agent writes one welcome in its first reply, unless a campaign or an earlier reply already opened the conversation.
  WELCOME_ON_FIRST_REPLY = true
  # On the widget the follow-up question gets its own bubble.
  SEPARATE_FOLLOW_UP_ON_WIDGET = true

  # On the widget the bubbles of one reply arrive like a person typing: the first after at least
  # REPLY_MIN_TYPING_MS of typing since the visitor's message, each later text bubble after a pause that grows with
  # its length (REPLY_PAUSE_BASE_MS + REPLY_PAUSE_PER_CHAR_MS per character, kept between the min and max).
  # Cards and forms come with the bubble before them.
  REPLY_MIN_TYPING_MS = 1000
  REPLY_PAUSE_BASE_MS = 500
  REPLY_PAUSE_PER_CHAR_MS = 12
  REPLY_PAUSE_MIN_MS = 800
  REPLY_PAUSE_MAX_MS = 2500

  def self.bubble_pause_ms(text)
    (REPLY_PAUSE_BASE_MS + (REPLY_PAUSE_PER_CHAR_MS * text.to_s.length)).clamp(REPLY_PAUSE_MIN_MS, REPLY_PAUSE_MAX_MS)
  end

  # Web widget proactive check-in timing (seconds):
  # Web widget proactive check-in timing (seconds):
  # Fast, opinionated defaults for live website visitors on the widget.
  # 40 seconds when the assistant asked a clarifying / qualification / options question and awaits an answer.
  # 60 seconds (1 minute) when the assistant gave a complete answer and no question is pending.
  WIDGET_CHECK_IN_AWAITING_ANSWER_SECONDS = 40
  WIDGET_CHECK_IN_COMPLETED_ANSWER_SECONDS = 60

  def self.widget_check_in_awaiting_seconds(assistant)
    resolve_widget_delay(assistant&.config&.dig('widget_check_in_awaiting_seconds'),
                         'CAPTAIN_WIDGET_CHECK_IN_AWAITING_SECONDS',
                         WIDGET_CHECK_IN_AWAITING_ANSWER_SECONDS)
  end

  def self.widget_check_in_completed_seconds(assistant)
    resolve_widget_delay(assistant&.config&.dig('widget_check_in_completed_seconds'),
                         'CAPTAIN_WIDGET_CHECK_IN_COMPLETED_SECONDS',
                         WIDGET_CHECK_IN_COMPLETED_ANSWER_SECONDS)
  end

  def self.resolve_widget_delay(configured, config_key, default_seconds)
    candidates = [configured, GlobalConfig.get_value(config_key), ENV.fetch(config_key, nil)]
    candidates.lazy.map { |v| v.presence&.to_i }.find { |v| v&.positive? } || default_seconds
  end

  # After a quiet period the agent sends one short check-in (a lead offer for prospects), then auto-resolve applies.
  # It comes after half of auto_resolve_after, rounded down to 5 minutes and kept between 5 and 30 minutes.
  CHECK_IN_STEP_MINUTES = 5
  CHECK_IN_MIN_MINUTES = 5
  CHECK_IN_MAX_MINUTES = 30
  CHECK_IN_WITHOUT_AUTO_RESOLVE_MINUTES = 15
  # Conversations quiet for longer than this get no check-in, so old pending chats are never woken up.
  CHECK_IN_LOOKBACK = 24.hours
  CHECK_IN_HISTORY_MESSAGES = 6
  CHECK_IN_MAX_LENGTH = 200
  CHECK_IN_TIMEOUT_SECONDS = 10.0

  def self.check_in_after_minutes(assistant)
    return CHECK_IN_WITHOUT_AUTO_RESOLVE_MINUTES if assistant.inactive_conversation_resolution_disabled?

    half = (assistant.inactivity_threshold_minutes / 2 / CHECK_IN_STEP_MINUTES) * CHECK_IN_STEP_MINUTES
    half.clamp(CHECK_IN_MIN_MINUTES, CHECK_IN_MAX_MINUTES)
  end

  # The content one agent's merchant set that shapes its replies, read in one place.
  Settings = Data.define(:assistant) do
    def limits = assistant.limits

    def leads_enabled? = assistant.leads_enabled?

    def business_type = assistant.effective_business_type

    # The behaviour part of the reply prompt: answer shape, business add-on, limits and lead capture.
    # `behaviour` feeds snippets/behaviour.liquid (role, first-reply welcome, limits) in every reply prompt.
    def prompt_context
      identity = { name: assistant.name, product_name: assistant.product_name || 'this product', limits: limits }
      schema_v2 = Captain::ResponseSchema.v2?(assistant.account_id)
      { **assistant.business_prompt_context, limits: limits, **assistant.lead_prompt_context, behaviour: identity, reply_schema_v2: schema_v2 }
    end
  end

  def self.for(assistant) = Settings.new(assistant)
end

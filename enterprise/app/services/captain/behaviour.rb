# How every Captain agent behaves. ChatOctave decides this; merchants only set content (knowledge, instructions, tone).
module Captain::Behaviour
  # Decides per conversation whether the visitor is a customer, a prospect or a shopper.
  ROLE = 'adaptive'.freeze
  # The agent writes one welcome in its first reply, unless a campaign or an earlier reply already opened the conversation.
  WELCOME_ON_FIRST_REPLY = true
  # On the widget the follow-up question gets its own bubble.
  SEPARATE_FOLLOW_UP_ON_WIDGET = true

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
    def prompt_context
      { **assistant.business_prompt_context, limits: limits, **assistant.lead_prompt_context }
    end
  end

  def self.for(assistant) = Settings.new(assistant)
end

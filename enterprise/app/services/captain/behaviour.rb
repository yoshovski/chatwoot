# How every Captain agent behaves. ChatOctave decides this; merchants only set content (knowledge, instructions, tone).
module Captain::Behaviour
  # Decides per conversation whether the visitor is a customer, a prospect or a shopper.
  ROLE = 'adaptive'.freeze
  # The agent writes one welcome in its first reply, unless a campaign or an earlier reply already opened the conversation.
  WELCOME_ON_FIRST_REPLY = true
  # On the widget the follow-up question gets its own bubble.
  SEPARATE_FOLLOW_UP_ON_WIDGET = true

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

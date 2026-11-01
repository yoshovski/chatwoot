# How every Captain agent behaves. ChatOctave decides this; merchants only set content (knowledge, instructions, tone).
module Captain::Behaviour
  # Decides per conversation whether the visitor is a customer, a prospect or a shopper.
  ROLE = 'adaptive'.freeze
  # The agent writes one welcome in its first reply, unless a campaign or an earlier reply already opened the conversation.
  WELCOME_ON_FIRST_REPLY = true
  # On the widget the follow-up question gets its own bubble.
  SEPARATE_FOLLOW_UP_ON_WIDGET = true
end

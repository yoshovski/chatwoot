# The AI welcome of a first reply comes before the answer: its own bubble on the widget, the start of the message on
# other channels (see Channel). The draft already removed a welcome the model repeated.
# After the early welcome (Captain::Reply::EarlyWelcome) the reply adds none.
class Captain::Reply::Policies::Greeting < Captain::Reply::Policies::Base
  def apply
    return if context.state&.dig(:welcomed_early)

    workspace.greeting = draft.welcome_part if Captain::Behaviour::WELCOME_ON_FIRST_REPLY
  end
end

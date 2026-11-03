# The AI welcome of a first reply opens the first answer bubble. The draft already removed a welcome the model repeated.
class Captain::Reply::Policies::Greeting < Captain::Reply::Policies::Base
  def apply
    workspace.greeting = draft.welcome_part if Captain::Behaviour::WELCOME_ON_FIRST_REPLY
  end
end

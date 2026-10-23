# What the agent does when a colleague would be needed, chosen per assistant for when the team is
# online and when it is offline. The team is offline outside the inbox's working hours, or when no
# inbox member is online.
class Captain::Conversation::HandoffPolicy
  ACTIONS = %w[transfer keep].freeze

  def initialize(assistant:, conversation:)
    @assistant = assistant
    @conversation = conversation
  end

  def team_online?
    return @team_online if defined?(@team_online)

    inbox = @conversation.inbox
    @team_online = !inbox.out_of_office? && inbox.available_agents.exists?
  end

  def keep? = action == 'keep'

  def keep_message = @assistant.config['no_handoff_message'].presence || I18n.t('conversations.captain.no_handoff')

  # The message sent when the conversation moves to the team.
  def handoff_message
    offline_message = @assistant.config['offline_handoff_message'].presence unless team_online?
    offline_message || @assistant.config['handoff_message'].presence || I18n.t('conversations.captain.handoff')
  end

  def prompt_instruction
    if keep?
      "No colleague can take over this conversation right now. Don't hand off or promise that a colleague will reply. " \
        "When a colleague would be needed, tell the customer this, in their language: #{keep_message} Then keep helping where you can."
    elsif !team_online?
      offline_message = @assistant.config['offline_handoff_message'].presence
      ['Your team is offline right now. When you hand off, say a colleague will reply when they are back, not right away.',
       ("Use this message, in the customer's language: #{offline_message}" if offline_message)].compact.join(' ')
    end
  end

  private

  def action
    key = team_online? ? 'handoff_when_online' : 'handoff_when_offline'
    @assistant.config[key].presence || 'transfer'
  end
end

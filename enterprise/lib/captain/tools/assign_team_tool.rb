# Assigns the conversation to the team the reference fixes. It doesn't hand off: the AI agent keeps answering.
class Captain::Tools::AssignTeamTool < Captain::Tools::BuiltInActionTool
  description 'Assigns this conversation to a team'
  fixed_param :team_id

  class << self
    def team(assistant, team_id) = assistant.account.teams.find_by(id: team_id.to_s)

    def fixed_summary(assistant, params) = "assigns the conversation to the #{team(assistant, params['team_id'])&.name || 'team'} team"

    private

    def validate_fixed_params(assistant, params)
      team(assistant, params['team_id']) ? [] : ["no team #{params['team_id']}"]
    end
  end

  def perform(tool_context)
    state = tool_context.state
    error = fixed_params_error(state)
    return error if error

    team = self.class.team(@assistant, fixed(:team_id))
    return "Would assign the conversation to #{team.name} (preview)." if state[:source] == 'playground'

    conversation = find_conversation(state)
    return failure_result('Conversation not found', state) unless conversation

    conversation.update!(team: team)
    log_tool_usage('assigned_team', conversation_id: conversation.id, team_id: team.id)
    "Assigned to the #{team.name} team. Keep helping; this isn't a handoff."
  end
end

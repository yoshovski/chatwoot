# Assigns the conversation to a fixed agent, or round robin among the online agents of a team (or of the inbox).
class Captain::Tools::AssignAgentTool < Captain::Tools::BuiltInActionTool
  ROUND_ROBIN = 'round_robin'.freeze

  description 'Assigns this conversation to a person on your team'
  fixed_param :agent_id
  fixed_param :team_id, required: false

  class << self
    def agent(assistant, agent_id) = assistant.account.users.find_by(id: agent_id.to_s)
    def team(assistant, team_id) = team_id.present? ? assistant.account.teams.find_by(id: team_id.to_s) : nil

    def fixed_summary(assistant, params)
      if params['agent_id'] == ROUND_ROBIN
        team_name = team(assistant, params['team_id'])&.name
        return "assigns the next available agent#{" of #{team_name}" if team_name}"
      end

      "assigns the conversation to #{agent(assistant, params['agent_id'])&.available_name || 'an agent'}"
    end

    private

    def validate_fixed_params(assistant, params)
      return ["no team #{params['team_id']}"] if params['team_id'].present? && team(assistant, params['team_id']).nil?
      return [] if params['agent_id'] == ROUND_ROBIN

      agent(assistant, params['agent_id']) ? [] : ["no agent #{params['agent_id']}"]
    end
  end

  def perform(tool_context)
    state = tool_context.state
    error = fixed_params_error(state)
    return error if error
    return 'Would assign the conversation (preview).' if state[:source] == 'playground'

    conversation = find_conversation(state)
    return failure_result('Conversation not found', state) unless conversation

    assign(conversation)
  end

  private

  def assign(conversation)
    team = self.class.team(@assistant, fixed(:team_id))
    agent = fixed(:agent_id) == ROUND_ROBIN ? next_agent(conversation, team) : self.class.agent(@assistant, fixed(:agent_id))
    conversation.update!({ team: team, assignee: agent }.compact)
    log_tool_usage('assigned_agent', conversation_id: conversation.id, agent_id: agent&.id, team_id: team&.id)
    return "No agent is available right now#{" (#{team.name} has it)" if team}. Don't promise a reply time." unless agent

    "Assigned to #{agent.available_name}. Keep helping until they reply."
  end

  def next_agent(conversation, team)
    allowed = conversation.inbox.inbox_members.pluck(:user_id)
    allowed &= team.team_members.pluck(:user_id) if team
    AutoAssignment::AgentAssignmentService.new(conversation: conversation, allowed_agent_ids: allowed.map(&:to_s)).find_assignee
  end
end

require 'rails_helper'

RSpec.describe Captain::Tools::AssignAgentTool do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:tool_context) { Struct.new(:state).new({ conversation: { id: conversation.id } }) }

  it 'assigns a fixed agent' do
    result = described_class.new(assistant, fixed_params: { agent_id: agent.id.to_s }).perform(tool_context)

    expect(result).to include("Assigned to #{agent.available_name}")
    expect(conversation.reload.assignee).to eq(agent)
  end

  it 'assigns the next online agent of the team by round robin' do
    team = create(:team, account: account)
    offline_member = create(:user, account: account, role: :agent)
    [agent, offline_member].each do |user|
      create(:inbox_member, inbox: inbox, user: user)
      create(:team_member, team: team, user: user)
    end
    allow(OnlineStatusTracker).to receive(:get_available_users).and_return({ agent.id.to_s => 'online' })

    tool = described_class.new(assistant, fixed_params: { agent_id: 'round_robin', team_id: team.id.to_s })
    tool.perform(tool_context)

    expect(conversation.reload).to have_attributes(assignee: agent, team: team)
  end

  it 'keeps the team when nobody is online' do
    team = create(:team, account: account)
    allow(OnlineStatusTracker).to receive(:get_available_users).and_return({})

    result = described_class.new(assistant, fixed_params: { agent_id: 'round_robin', team_id: team.id.to_s }).perform(tool_context)

    expect(result).to include('No agent is available')
    expect(conversation.reload).to have_attributes(assignee: nil, team: team)
  end

  it 'rejects an agent of another account' do
    expect(described_class.fixed_param_errors(assistant, 'agent_id' => create(:user).id.to_s)).to include(/no agent/)
  end
end

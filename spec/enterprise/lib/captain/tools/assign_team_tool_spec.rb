require 'rails_helper'

RSpec.describe Captain::Tools::AssignTeamTool do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:team) { create(:team, account: account, name: 'Sales') }
  let(:conversation) { create(:conversation, account: account, status: :pending) }
  let(:tool_context) { Struct.new(:state).new({ conversation: { id: conversation.id } }) }

  it 'assigns the team without handing off' do
    tool = described_class.new(assistant, fixed_params: { team_id: team.id.to_s })

    expect(tool.parameters).to be_empty
    expect(tool.description).to eq('Assigns this conversation to a team. Assigns the conversation to the sales team')
    expect(tool.perform(tool_context)).to include('Assigned to the sales team')
    expect(conversation.reload).to have_attributes(team: team, status: 'pending')
  end

  it 'rejects a team of another account' do
    other_team = create(:team)

    expect(described_class.fixed_param_errors(assistant, 'team_id' => other_team.id.to_s)).to eq(["no team #{other_team.id}"])
  end
end

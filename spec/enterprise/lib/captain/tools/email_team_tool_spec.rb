require 'rails_helper'

RSpec.describe Captain::Tools::EmailTeamTool do
  let(:account) { create(:account) }
  let(:templates) { { 'demo' => { 'subject' => 'New demo request', 'body' => "{{ contact.name }} wants a demo.\n{{ summary }}" } } }
  let(:assistant) { create(:captain_assistant, account: account, config: { 'email_templates' => templates }) }
  let(:team) { create(:team, account: account, name: 'Sales') }
  let(:member) { create(:user, account: account, email: 'sam@harbor-bikes.test') }
  let(:contact) { create(:contact, account: account, name: 'Jamie') }
  let(:conversation) { create(:conversation, account: account, contact: contact) }
  let(:tool_context) { Struct.new(:state).new({ conversation: { id: conversation.id } }) }

  before { create(:team_member, team: team, user: member) }

  it 'emails the team the template with the summary' do
    tool = described_class.new(assistant, fixed_params: { recipient: "team:#{team.id}", template: 'demo' })

    expect(tool.parameters.keys).to eq([:summary])
    expect { tool.perform(tool_context, summary: '40 people, wants SSO') }.to have_enqueued_mail(Captain::ActionsMailer, :team_email)
      .with(conversation, ['sam@harbor-bikes.test'], 'New demo request', "Jamie wants a demo.\n40 people, wants SSO")
  end

  it 'says so when the conversation has no assignee' do
    tool = described_class.new(assistant, fixed_params: { recipient: 'assignee', template: 'demo' })

    expect(tool.perform(tool_context, summary: 'x')).to include("wasn't sent (no recipients)")
  end

  it 'validates the recipient' do
    expect(described_class.fixed_param_errors(assistant, 'recipient' => 'everyone', 'template' => 'demo')).to eq(['no recipient everyone'])
  end
end

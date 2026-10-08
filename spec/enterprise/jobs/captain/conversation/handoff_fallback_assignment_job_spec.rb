# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Captain::Conversation::HandoffFallbackAssignmentJob, type: :job do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: nil).tap(&:open!) }

  before do
    account.enable_features!('captain_integration_v2')
    create(:captain_inbox, captain_assistant: assistant, inbox: inbox)
  end

  describe '#perform' do
    it 'assigns the fallback agent when the conversation is open, unassigned, and the agent is an inbox member' do
      inbox.inbox_members.create!(user: agent)
      assistant.update!(config: assistant.config.merge('handoff_fallback_agent_id' => agent.id))

      described_class.perform_now(conversation, assistant)

      expect(conversation.reload.assignee).to eq(agent)
    end

    it 'leaves an already-assigned conversation alone' do
      other_agent = create(:user, account: account, role: :agent)
      inbox.inbox_members.create!(user: agent)
      inbox.inbox_members.create!(user: other_agent)
      conversation.update!(assignee: other_agent)
      assistant.update!(config: assistant.config.merge('handoff_fallback_agent_id' => agent.id))

      described_class.perform_now(conversation, assistant)

      expect(conversation.reload.assignee).to eq(other_agent)
    end

    it 'leaves a resolved conversation alone' do
      inbox.inbox_members.create!(user: agent)
      conversation.update!(status: :resolved)
      assistant.update!(config: assistant.config.merge('handoff_fallback_agent_id' => agent.id))

      described_class.perform_now(conversation, assistant)

      expect(conversation.reload.assignee).to be_nil
    end

    it 'assigns the fallback team when no agent is configured' do
      team = create(:team, account: account)
      assistant.update!(config: assistant.config.merge('handoff_fallback_team_id' => team.id))

      described_class.perform_now(conversation, assistant)

      expect(conversation.reload.team).to eq(team)
    end

    it 'falls back to team when the configured agent is not a member of the conversation inbox' do
      team = create(:team, account: account)
      inbox_member = inbox.inbox_members.create!(user: agent)
      assistant.update!(config: assistant.config.merge('handoff_fallback_agent_id' => agent.id, 'handoff_fallback_team_id' => team.id))
      inbox_member.destroy!

      described_class.perform_now(conversation, assistant)

      expect(conversation.reload.assignee).to be_nil
      expect(conversation.reload.team).to eq(team)
    end

    it 'does nothing if captain_integration_v2 is disabled' do
      account.disable_features!('captain_integration_v2')
      inbox.inbox_members.create!(user: agent)
      assistant.update!(config: assistant.config.merge('handoff_fallback_agent_id' => agent.id))

      described_class.perform_now(conversation, assistant)

      expect(conversation.reload.assignee).to be_nil
    end

    it 'does nothing if neither agent nor team is configured' do
      assistant.update!(config: assistant.config.merge('handoff_fallback_agent_id' => nil, 'handoff_fallback_team_id' => nil))

      described_class.perform_now(conversation, assistant)

      expect(conversation.reload.assignee).to be_nil
      expect(conversation.reload.team).to be_nil
    end
  end
end

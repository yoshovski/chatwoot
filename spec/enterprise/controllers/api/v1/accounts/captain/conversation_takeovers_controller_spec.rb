require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Captain::ConversationTakeovers', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:assistant) { create(:captain_assistant, account: account, config: { 'continue_while_waiting' => true }) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, status: :pending, ai_assignee: assistant) }

  before { create(:captain_inbox, captain_assistant: assistant, inbox: inbox) }

  describe 'POST /api/v1/accounts/:account_id/captain/conversations/:conversation_id/takeover' do
    it 'hands the conversation from Captain to the agent' do
      create(:inbox_member, user: agent, inbox: inbox)

      post "/api/v1/accounts/#{account.id}/captain/conversations/#{conversation.display_id}/takeover",
           headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(conversation.reload).to have_attributes(status: 'open', assignee: agent, ai_assignee: nil)
      expect(conversation.label_list).to include('human-active')
    end

    it 'does not allow an agent without access to the conversation' do
      post "/api/v1/accounts/#{account.id}/captain/conversations/#{conversation.display_id}/takeover",
           headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(conversation.reload.status).to eq('pending')
    end
  end
end

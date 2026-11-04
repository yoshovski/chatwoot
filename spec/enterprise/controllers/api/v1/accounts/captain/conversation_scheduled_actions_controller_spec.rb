require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Captain::ConversationScheduledActions', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:path) { "/api/v1/accounts/#{account.id}/captain/conversations/#{conversation.display_id}/scheduled_actions" }

  before { create(:inbox_member, user: agent, inbox: inbox) }

  describe 'GET scheduled_actions' do
    it 'lists only the pending actions of that conversation' do
      pending_action = create(:captain_scheduled_action, conversation: conversation, due_at: 2.hours.from_now)
      create(:captain_scheduled_action, conversation: conversation, status: :cancelled)
      create(:captain_scheduled_action, account: account)

      get path, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['payload']).to eq(
        [{ 'id' => pending_action.id, 'kind' => 'follow_up_message', 'due_at' => pending_action.due_at.to_i,
           'created_at' => pending_action.created_at.to_i }]
      )
    end

    it 'does not allow an agent without access to the conversation' do
      other_agent = create(:user, account: account, role: :agent)

      get path, headers: other_agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'DELETE scheduled_actions/:id' do
    it 'cancels a pending action' do
      action = create(:captain_scheduled_action, conversation: conversation)

      delete "#{path}/#{action.id}", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:no_content)
      expect(action.reload).to have_attributes(status: 'cancelled', cancel_reason: 'agent')
    end
  end
end

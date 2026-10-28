require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Captain::Home', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/captain/home" }

  it 'returns empty counts for a new account' do
    get url, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['setup']).to include('ai_agent' => false, 'knowledge' => false, 'chat_widget' => false, 'mailbox' => false)
    expect(response.parsed_body['quick_actions']).to eq('unassigned_conversations' => 0, 'unanswered_questions' => 0, 'live_visitors' => 0)
    expect(response.parsed_body['performance']).to eq('ai_resolution_rate' => 0, 'sales_assisted' => 0, 'leads_captured' => 0)
    expect(response.parsed_body['project_status']).to include('widget_installed' => false, 'domain' => 'none')
  end

  describe 'with data' do
    let(:assistant) { create(:captain_assistant, account: account) }
    let(:widget_inbox) { create(:inbox, account: account, channel: create(:channel_widget, account: account)) }
    let(:conversation) { create(:conversation, account: account, inbox: widget_inbox, assignee: nil) }

    before do
      create(:inbox_member, user: agent, inbox: widget_inbox)
      conversation # opened before the AI agent joins the inbox, so it isn't pending
      create(:captain_inbox, captain_assistant: assistant, inbox: widget_inbox)
      create(:captain_assistant_response, assistant: assistant, account: account, status: :approved)
      Captain::KnowledgeGaps::Recorder.new(assistant: assistant, conversation: conversation, question: 'Do you ship to Spain?',
                                           reason: 'no_source').record
      Captain::AgentSession.create!(assistant: assistant, session_type: :assistant, subject: conversation,
                                    sources: [{ index: 1, reference: 'product:mug', kind: 'product', used: true }])
      note = create(:message, account: account, conversation: conversation, private: true, message_type: :outgoing)
      conversation.update!(additional_attributes: { 'business_lead_captured' => true, 'business_lead_summary_note_id' => note.id })
      create(:portal, account: account, custom_domain: 'help.example.com', ssl_settings: { 'cf_status' => 'active' })
    end

    it 'counts each card for an agent' do
      get url, headers: agent.create_new_auth_token, as: :json

      body = response.parsed_body
      expect(body['setup']).to include('ai_agent' => true, 'knowledge' => true, 'agent_inbox' => true, 'chat_widget' => true,
                                       'teammate' => true)
      expect(body['quick_actions']).to include('unassigned_conversations' => 1, 'unanswered_questions' => 1)
      expect(body['performance']).to include('sales_assisted' => 1, 'leads_captured' => 1)
      expect(body['project_status']).to eq('widget_installed' => true, 'mailbox_connected' => false, 'domain' => 'verified')
      expect(body['usage']['ai_replies']).to include('used' => 1)
    end
  end
end

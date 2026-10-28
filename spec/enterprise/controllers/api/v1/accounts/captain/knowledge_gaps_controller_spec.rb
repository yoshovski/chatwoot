require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Captain::KnowledgeGaps', type: :request do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:gap) do
    Captain::KnowledgeGaps::Recorder.new(assistant: assistant, conversation: conversation, question: 'Do you ship to Spain?',
                                         reason: 'handoff').record
  end
  let(:base_url) { "/api/v1/accounts/#{account.id}/captain/knowledge_gaps" }

  before { gap }

  describe 'GET index' do
    it 'returns open gaps with their counts and reasons, most frequent first' do
      frequent = Captain::KnowledgeGaps::Recorder.new(assistant: assistant, conversation: conversation, question: 'Is there a warranty?',
                                                      reason: 'no_source').record
      frequent.update!(occurrences_count: 5)
      assistant.knowledge_gaps.create!(question: 'Old', normalized_question: 'old', last_seen_at: Time.current, status: :dismissed)

      get base_url, params: { assistant_id: assistant.id }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].pluck('id')).to eq([frequent.id, gap.id])
      expect(response.parsed_body['payload'].last).to include('occurrences_count' => 1, 'reasons' => { 'handoff' => 1, 'no_source' => 0 })
      expect(response.parsed_body['meta']).to include('total_count' => 2)
    end

    it 'filters by search' do
      get base_url, params: { search: 'warranty' }, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['payload']).to be_empty
    end

    it 'shows agents only gaps from conversations they can access' do
      create(:inbox_member, user: agent, inbox: inbox)
      hidden_conversation = create(:conversation, account: account, inbox: create(:inbox, account: account))
      Captain::KnowledgeGaps::Recorder.new(assistant: assistant, conversation: hidden_conversation, question: 'Hidden question',
                                           reason: 'no_source').record

      get base_url, headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['payload'].pluck('id')).to eq([gap.id])
    end

    it 'requires authentication' do
      get base_url, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET show' do
    it 'returns the latest conversations' do
      get "#{base_url}/#{gap.id}", headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['occurrences']).to contain_exactly(
        include('reason' => 'handoff', 'conversation' => { 'id' => conversation.id, 'display_id' => conversation.display_id })
      )
    end
  end

  describe 'POST answer' do
    it 'creates an approved FAQ and marks the gap answered' do
      expect do
        post "#{base_url}/#{gap.id}/answer", params: { knowledge_gap: { question: 'Do you ship to Spain?', answer: 'Yes, in 3 days.' } },
                                             headers: admin.create_new_auth_token, as: :json
      end.to change(assistant.responses.approved, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(gap.reload).to have_attributes(status: 'answered', response_id: assistant.responses.last.id)
    end

    it 'rejects a blank answer' do
      post "#{base_url}/#{gap.id}/answer", params: { knowledge_gap: { question: 'Q', answer: '' } },
                                           headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(gap.reload).to be_open
    end
  end

  describe 'POST dismiss' do
    it 'dismisses the gap' do
      post "#{base_url}/#{gap.id}/dismiss", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(gap.reload).to be_dismissed
    end

    it 'returns not found for a gap in another account' do
      other_gap = Captain::KnowledgeGaps::Recorder.new(
        assistant: create(:captain_assistant), conversation: create(:conversation), question: 'Elsewhere', reason: 'no_source'
      ).record

      post "#{base_url}/#{other_gap.id}/dismiss", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end

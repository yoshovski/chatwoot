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

  def record(question, reason: 'no_source', in_conversation: create(:conversation, account: account, inbox: inbox))
    Captain::KnowledgeGaps::Recorder.new(assistant: assistant, conversation: in_conversation, question: question, reason: reason).record
  end

  describe 'GET index' do
    before { gap.update!(kind: :knowledge, topic: 'Shipping') }

    it 'lists unanswered knowledge questions with counts, reasons and raw examples, most frequent first' do
      frequent = record('Is there a warranty?')
      record('is there a warranty??')
      frequent.update!(kind: :knowledge, question: 'What warranty do you give?', topic: 'Warranty')
      assistant.knowledge_gaps.create!(question: 'Old', normalized_question: 'old', last_seen_at: Time.current, status: :dismissed, kind: :knowledge)

      get base_url, params: { assistant_id: assistant.id }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].pluck('id')).to eq([frequent.id, gap.id])
      expect(response.parsed_body['payload'].first).to include('question' => 'What warranty do you give?', 'kind' => 'knowledge',
                                                               'topic' => 'Warranty', 'occurrences_count' => 2,
                                                               'examples' => ['is there a warranty??', 'Is there a warranty?'])
      expect(response.parsed_body['payload'].last).to include('occurrences_count' => 1, 'reasons' => { 'handoff' => 1, 'no_source' => 0 })
      expect(response.parsed_body['meta']).to include('total_count' => 2)
    end

    it 'leaves out questions from one conversation without a handoff, unclassified gaps and action requests' do
      record('Do you sell gift cards?').knowledge!
      record('Where is my order?', reason: 'handoff').update!(kind: :action_request, intent: 'order_status')
      record('Something not yet classified', reason: 'handoff')

      get base_url, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['payload'].pluck('id')).to eq([gap.id])
    end

    it 'lists dismissed knowledge questions' do
      gap.dismissed!

      get base_url, params: { view: 'dismissed' }, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['payload'].pluck('id')).to eq([gap.id])
    end

    it 'rejects an unknown view' do
      get base_url, params: { view: 'everything' }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'filters by search' do
      get base_url, params: { search: 'warranty' }, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['payload']).to be_empty
    end

    it 'shows agents only gaps and examples from conversations they can access' do
      create(:inbox_member, user: agent, inbox: inbox)
      hidden_conversation = create(:conversation, account: account, inbox: create(:inbox, account: account))
      record('Hidden question', reason: 'handoff', in_conversation: hidden_conversation).knowledge!
      record('do you ship to spain', in_conversation: hidden_conversation)

      get base_url, headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['payload'].pluck('id')).to eq([gap.id])
      expect(response.parsed_body['payload'].first['examples']).to eq(['Do you ship to Spain?'])
    end

    it 'requires authentication' do
      get base_url, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET topics' do
    it 'groups unanswered questions by topic, the busiest topic first' do
      gap.update!(kind: :knowledge, topic: 'Shipping', draft_answer: 'We ship to Spain in 3 days.')
      warranty = record('Is there a warranty?', reason: 'handoff')
      warranty.update!(kind: :knowledge, topic: 'Warranty', occurrences_count: 4)
      costs = record('What does shipping cost?', reason: 'handoff')
      costs.update!(kind: :knowledge, topic: 'Shipping')

      get "#{base_url}/topics", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].map { |group| [group['topic'], group['conversations_count']] }).to eq([['Warranty', 4], ['Shipping', 2]])
      shipping = response.parsed_body['payload'].last['gaps']
      expect(shipping.pluck('id')).to contain_exactly(gap.id, costs.id)
      expect(shipping.find { |item| item['id'] == gap.id }).to include('draft_answer' => 'We ship to Spain in 3 days.',
                                                                       'examples' => ['Do you ship to Spain?'])
    end
  end

  describe 'GET action_requests' do
    it 'counts open action requests per intent with examples' do
      tracking = record('can you check where is my order')
      tracking.update!(kind: :action_request, intent: 'order_status', question: 'Where is my order?')
      record('where is my package', in_conversation: conversation).update!(kind: :action_request, intent: 'order_status')
      record('cancel my order please').update!(kind: :action_request, intent: 'cancel', status: :dismissed)

      get "#{base_url}/action_requests", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload']).to contain_exactly(
        include('intent' => 'order_status', 'conversations_count' => 2,
                'examples' => contain_exactly('can you check where is my order', 'where is my package'))
      )
    end
  end

  describe 'POST bulk_dismiss' do
    it 'dismisses the open gaps the user can see' do
      other = record('Is there a warranty?')
      foreign = Captain::KnowledgeGaps::Recorder.new(
        assistant: create(:captain_assistant), conversation: create(:conversation), question: 'Elsewhere', reason: 'no_source'
      ).record

      post "#{base_url}/bulk_dismiss", params: { ids: [gap.id, other.id, foreign.id] }, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body).to eq('dismissed_count' => 2)
      expect([gap.reload, other.reload]).to all(be_dismissed)
      expect(foreign.reload).to be_open
    end

    it 'rejects a missing list' do
      post "#{base_url}/bulk_dismiss", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
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

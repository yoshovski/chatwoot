require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Captain::KnowledgeBriefs', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let!(:ready) { create(:captain_document, assistant: assistant, account: account, status: :available, content: 'About us text') }
  let!(:indexing) { create(:captain_document, assistant: assistant, account: account, status: :in_progress, content: 'Pricing text') }
  let(:url) { "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/knowledge_brief/generate" }

  it 'lets the job pick the sources when none are chosen' do
    post url, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:accepted)
    expect(Captain::Knowledge::GenerateBriefJob).to have_been_enqueued.with(assistant.id, nil, pick_sources: true)
  end

  it 'accepts chosen sources even when some are still indexing' do
    post url, params: { document_ids: [ready.id, indexing.id] }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:accepted)
    expect(Captain::Knowledge::GenerateBriefJob).to have_been_enqueued.with(assistant.id, [ready.id, indexing.id], pick_sources: false)
  end

  it 'rejects a choice with no ready source' do
    post url, params: { document_ids: [indexing.id] }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  describe 'GET examples' do
    let(:examples_url) { "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/knowledge_brief/examples" }

    it 'queues the first generation and returns no examples yet' do
      get examples_url, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['examples']).to be_nil
      expect(Captain::Knowledge::GenerateExamplesJob).to have_been_enqueued.with(assistant.id)
    end

    it 'returns stored examples without queueing while the business details are unchanged' do
      brief = Captain::KnowledgeBrief.create!(assistant: assistant)
      brief.update!(examples: { 'data' => { 'question' => 'Do you ship abroad?' }, 'fingerprint' => brief.examples_fingerprint })

      get examples_url, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body.dig('examples', 'question')).to eq('Do you ship abroad?')
      expect(Captain::Knowledge::GenerateExamplesJob).not_to have_been_enqueued
    end

    it 'regenerates examples written by an older prompt at the settling pace' do
      assistant.update!(created_at: 30.days.ago)
      brief = Captain::KnowledgeBrief.create!(assistant: assistant,
                                              published: { 'document_ids' => [ready.id], 'overview' => { 'text' => 'Old' }, 'topics' => [] })
      brief.update!(examples: { 'fingerprint' => 'old', 'requested_at' => 2.hours.ago.iso8601 })

      get examples_url, headers: admin.create_new_auth_token, as: :json

      expect(Captain::Knowledge::GenerateExamplesJob).to have_been_enqueued.with(assistant.id)
    end

    it 'waits a month between regenerations for a settled agent' do
      assistant.update!(created_at: 30.days.ago)
      brief = Captain::KnowledgeBrief.create!(assistant: assistant,
                                              published: { 'document_ids' => [ready.id], 'overview' => { 'text' => 'Old' }, 'topics' => [] })
      version = Captain::KnowledgeBrief::EXAMPLES_VERSION
      brief.update!(examples: { 'fingerprint' => 'old', 'version' => version, 'requested_at' => 2.days.ago.iso8601 })

      get examples_url, headers: admin.create_new_auth_token, as: :json
      expect(Captain::Knowledge::GenerateExamplesJob).not_to have_been_enqueued

      brief.update!(examples: { 'fingerprint' => 'old', 'version' => version, 'requested_at' => 31.days.ago.iso8601 })
      get examples_url, headers: admin.create_new_auth_token, as: :json
      expect(Captain::Knowledge::GenerateExamplesJob).to have_been_enqueued.with(assistant.id)
    end

    it 'refreshes hourly while the agent is new' do
      Captain::KnowledgeBrief.create!(assistant: assistant, examples: { 'fingerprint' => 'old', 'requested_at' => 2.hours.ago.iso8601 })

      get examples_url, headers: admin.create_new_auth_token, as: :json

      expect(Captain::Knowledge::GenerateExamplesJob).to have_been_enqueued.with(assistant.id)
    end
  end
end

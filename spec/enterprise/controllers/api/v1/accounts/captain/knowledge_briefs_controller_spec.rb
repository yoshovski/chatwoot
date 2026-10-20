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
end

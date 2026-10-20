require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Captain::DocumentSections', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:url) { "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/document_sections" }
  let(:source) do
    Captain::WebsiteSource.create!(assistant: assistant, url: 'https://www.example.com', status: 'ready',
                                   pages: %w[a b].map { |slug| { 'url' => "https://www.example.com/resources/#{slug}" } },
                                   selected_urls: %w[a b].map { |slug| "https://www.example.com/resources/#{slug}" })
  end
  let!(:resources) do
    %w[a b].map do |slug|
      create(:captain_document, assistant: assistant, account: account, status: :available,
                                external_link: "https://www.example.com/resources/#{slug}", metadata: { 'website_source_id' => source.id })
    end
  end
  let!(:help) do
    create(:captain_document, assistant: assistant, account: account, status: :available, external_link: 'https://support.example.com/hc/en-us/articles/1-Refunds')
  end

  def json_response = JSON.parse(response.body)

  it 'lists sections with a count per state' do
    resources.first.update!(enabled: false)

    get url, headers: agent.create_new_auth_token, as: :json

    expect(json_response['sections']).to eq(
      [{ 'key' => 'example.com/resources', 'count' => 2, 'ready' => 1, 'syncing' => 0, 'failed' => 0, 'paused' => 1 },
       { 'key' => 'support.example.com/articles', 'count' => 1, 'ready' => 1, 'syncing' => 0, 'failed' => 0, 'paused' => 0 }]
    )
  end

  it 'pauses a whole section and removes its pages from the website selection' do
    post url, params: { sections: ['example.com/resources'], section_action: 'pause' }, headers: admin.create_new_auth_token, as: :json

    expect(json_response['count']).to eq(2)
    expect(resources.map { |document| document.reload.enabled }).to eq([false, false])
    expect(help.reload).to be_enabled
    expect(source.reload.selected_urls).to eq([])
  end

  it 'resumes a paused section and selects its pages again' do
    resources.each { |document| document.update!(enabled: false) }
    source.update!(selected_urls: [])

    post url, params: { sections: ['example.com/resources'], section_action: 'resume' }, headers: admin.create_new_auth_token, as: :json

    expect(resources.map { |document| document.reload.enabled }).to eq([true, true])
    expect(source.reload.selected_urls).to match_array(resources.map(&:external_link))
  end

  it 'deletes a whole section' do
    post url, params: { sections: ['example.com/resources'], section_action: 'delete' }, headers: admin.create_new_auth_token, as: :json

    expect(Captain::Document.where(id: resources.map(&:id))).to be_empty
    expect(source.reload.selected_urls).to eq([])
  end

  it 'rejects unknown actions and agents' do
    post url, params: { sections: ['example.com/resources'], section_action: 'archive' }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)

    post url, params: { sections: ['example.com/resources'], section_action: 'delete' }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it 'filters the documents list to one section' do
    get "/api/v1/accounts/#{account.id}/captain/documents", params: { assistant_id: assistant.id, section: 'support.example.com/articles' },
                                                            headers: agent.create_new_auth_token

    expect(json_response['payload'].pluck('id')).to eq([help.id])
  end
end

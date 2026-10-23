require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Captain::WebsiteSources', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:source) do
    Captain::WebsiteSource.create!(assistant: assistant, url: 'https://www.example.com', status: 'ready',
                                   discovery_stats: { 'new_urls' => %w[https://www.example.com/new] },
                                   pages: %w[pricing new].map { |slug| { 'url' => "https://www.example.com/#{slug}" } })
  end
  let(:url) { "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/website_sources/#{source.id}" }

  def json_response = JSON.parse(response.body)

  it 'saves the selection together with the automatic-add choice' do
    patch url, params: { website_source: { selected_urls: %w[https://www.example.com/pricing], auto_add_pages: false } },
               headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(source.reload).to have_attributes(auto_add_pages: false, selected_urls: %w[https://www.example.com/pricing])
    expect(json_response).to include('auto_add_pages' => false)
    expect(json_response['pages'].to_h { |page| [page['url'], page['new']] })
      .to eq('https://www.example.com/pricing' => false, 'https://www.example.com/new' => true)
    expect(json_response['discovery_stats']).not_to have_key('new_urls')
  end

  it 'rejects an automatic-add choice that is not a boolean' do
    patch url, params: { website_source: { selected_urls: [], auto_add_pages: 'yes' } }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(source.reload.auto_add_pages).to be(true)
  end
end

require 'rails_helper'

RSpec.describe 'Customer directory', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:headers) { user.create_new_auth_token }
  let!(:contact) { create(:contact, :with_email, account: account, name: 'Alex') }
  let!(:another) { create(:contact, :with_email, account: account, name: 'Bea') }
  let(:path) { "/api/v1/accounts/#{account.id}/contacts/directory" }

  it 'requires authentication for both directory and counts' do
    get path
    expect(response).to have_http_status(:unauthorized)
    get "/api/v1/accounts/#{account.id}/contacts/segments"
    expect(response).to have_http_status(:unauthorized)
  end

  it 'returns counts in one account-scoped response' do
    create(:contact, :with_email)
    get "/api/v1/accounts/#{account.id}/contacts/segments", headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['payload'].find { |item| item['id'] == 'all' }['count']).to eq(2)
  end

  it 'sorts by conversation count and includes labels, source and website activity without contact inbox tokens' do
    create_list(:conversation, 2, account: account, contact: another)
    inbox = create(:inbox, account: account)
    create(:contact_inbox, contact: another, inbox: inbox,
                           website_activity: { 'current_page' => { 'url' => 'https://shop.example.com/help', 'last_seen_at' => Time.current.iso8601 },
                                               'arrival' => { 'utm_source' => 'newsletter' } })
    another.update_labels(['returning'])
    get path, params: { sort: '-conversations_count' }, headers: headers
    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body['meta']['count']).to eq(2)
    expect(body['payload'].map { |item| item['id'] }).to eq([another.id, contact.id])
    expect(body['payload'].first).to include('conversations_count' => 2, 'labels' => ['returning'])
    expect(body['payload'].first['website_activity'].dig('arrival', 'utm_source')).to eq('newsletter')
    expect(body['payload'].first).not_to have_key('contact_inboxes')
  end

  it 'searches inside the selected segment and does not expose other accounts' do
    contact.update!(created_at: 10.days.ago)
    create(:contact, :with_email, name: 'Alex')
    get path, params: { segment: 'new', q: 'Alex' }, headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['payload']).to eq([])
    get path, params: { q: 'Alex' }, headers: headers
    expect(response.parsed_body['payload'].map { |item| item['id'] }).to eq([contact.id])
  end

  it 'rejects unknown sorting, malformed pages and foreign segment references' do
    get path, params: { sort: 'name DESC' }, headers: headers
    expect(response).to have_http_status(:unprocessable_entity)
    get path, params: { page: '-1' }, headers: headers
    expect(response).to have_http_status(:unprocessable_entity)
    foreign = create(:custom_filter, filter_type: :contact)
    get path, params: { segment: "custom:#{foreign.id}" }, headers: headers
    expect(response).to have_http_status(:not_found)
  end

  it 'saves a usable segment through the existing filter builder contract' do
    post "/api/v1/accounts/#{account.id}/custom_filters", headers: headers, as: :json,
                                                          params: {
                                                            custom_filter: {
                                                              name: 'Has email', filter_type: 1,
                                                              query: { payload: [{ attribute_key: 'email', filter_operator: 'contains',
                                                                                   values: ['@'], attribute_model: 'standard' }] }
                                                            }
                                                          }
    expect(response).to have_http_status(:ok)
    id = response.parsed_body['id']
    get path, params: { segment: "custom:#{id}" }, headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['meta']['count']).to eq(2)
  end

  it 'rejects malformed contact conditions before saving them' do
    expect do
      post "/api/v1/accounts/#{account.id}/custom_filters", headers: headers, as: :json,
                                                            params: { custom_filter: { name: 'Broken', filter_type: 1, query: { payload: [{}] } } }
    end.not_to change(CustomFilter, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end
end

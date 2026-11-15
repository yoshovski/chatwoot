require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Captain::Leads', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:url) { "/api/v1/accounts/#{account.id}/captain/leads" }
  let(:attributes) do
    { 'business_lead_captured' => true, 'business_lead_captured_at' => '2026-11-15T10:00:00Z',
      'captain_summary' => { 'status' => 'lead', 'lead' => { 'type' => 'wholesale', 'summary' => 'Quote for 200 mugs',
                                                             'fields' => { 'company' => 'Sample shop' } } } }
  end
  let!(:conversation) { create(:conversation, account: account, inbox: inbox, additional_attributes: attributes) }

  it 'lists captured leads from the stored summary with default status and no owner' do
    create(:conversation, account: account, inbox: inbox)
    get url, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['payload']).to contain_exactly(
      a_hash_including('id' => conversation.display_id, 'wants' => 'Quote for 200 mugs', 'company' => 'Sample shop',
                       'status' => 'new', 'owner' => nil, 'hubspot' => 'off', 'captured_at' => '2026-11-15T10:00:00Z')
    )
    expect(response.parsed_body['meta']).to include('total' => 1, 'counts' => { 'new' => 1, 'contacted' => 0, 'won' => 0, 'lost' => 0 })
  end

  it 'keeps inaccessible leads out of the list, counts, export and edits' do
    headers = agent.create_new_auth_token
    get url, headers: headers, as: :json
    expect(response.parsed_body['payload']).to be_empty
    expect(response.parsed_body.dig('meta', 'counts').values.sum).to eq(0)

    get "#{url}/export", headers: headers
    expect(response).to have_http_status(:ok)
    expect(CSV.parse(response.body).size).to eq(1)

    patch "#{url}/#{conversation.display_id}", params: { status: 'won' }, headers: headers, as: :json
    expect(response).to have_http_status(:not_found)
  end

  it 'respects custom roles for both listing and export' do
    create(:inbox_member, inbox: inbox, user: agent)
    role = create(:custom_role, account: account, permissions: ['conversation_participating_manage'])
    account.account_users.find_by!(user: agent).update!(custom_role: role)
    headers = agent.create_new_auth_token
    get url, headers: headers
    expect(response.parsed_body['payload']).to be_empty

    conversation.update!(assignee: agent)
    get url, headers: headers
    expect(response.parsed_body['payload'].pluck('id')).to eq([conversation.display_id])
    get "#{url}/export", headers: headers
    expect(response).to have_http_status(:ok)
    expect(CSV.parse(response.body, headers: true).size).to eq(1)
  end

  it 'shows only confirmed HubSpot sync state rather than assuming delivery' do
    create(:integrations_hook, :hubspot, account: account)
    headers = admin.create_new_auth_token
    get url, headers: headers
    expect(response.parsed_body['payload'].first['hubspot']).to eq('not_synced')

    conversation.contact.update!(additional_attributes: { 'hubspot_sync_status' => 'synced' })
    get url, headers: headers
    expect(response.parsed_body['payload'].first['hubspot']).to eq('synced')
  end

  it 'allows an inbox member to update a lead without changing conversation ownership or its summary' do
    create(:inbox_member, inbox: inbox, user: agent)
    patch "#{url}/#{conversation.display_id}", params: { status: 'contacted', owner_id: agent.id },
                                               headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('status' => 'contacted', 'owner' => { 'id' => agent.id, 'name' => agent.name })
    expect(conversation.reload.additional_attributes).to include(attributes)
    expect(conversation.assignee_id).to be_nil

    patch "#{url}/#{conversation.display_id}", params: { owner_id: nil }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['owner']).to be_nil
  end

  it 'rejects foreign owners, malformed owner IDs and invalid statuses without saving' do
    foreign = create(:user)
    [{ owner_id: foreign.id }, { owner_id: agent.id.to_s }, { status: 'resolved' }, { status: nil }, {}].each do |params|
      patch "#{url}/#{conversation.display_id}", params: params, headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
    expect(conversation.reload.additional_attributes).not_to have_key('lead_management')
  end

  it 'cannot read another account or update an uncaptured conversation' do
    foreign = create(:account)
    get "/api/v1/accounts/#{foreign.id}/captain/leads", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)

    uncaptured = create(:conversation, account: account, inbox: inbox)
    patch "#{url}/#{uncaptured.display_id}", params: { status: 'won' }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)
  end

  it 'paginates and filters while keeping global status counts' do
    create_list(:conversation, 25, account: account, inbox: inbox, additional_attributes: attributes)
    conversation.update!(additional_attributes: attributes.merge('lead_management' => { 'status' => 'won' }))
    get url, params: { page: 2 }, headers: admin.create_new_auth_token
    expect(response.parsed_body['payload'].size).to eq(1)
    expect(response.parsed_body.dig('meta', 'total')).to eq(26)

    get url, params: { status: 'won' }, headers: admin.create_new_auth_token
    expect(response.parsed_body['payload'].pluck('id')).to eq([conversation.display_id])
    expect(response.parsed_body.dig('meta', 'counts', 'new')).to eq(25)
  end

  it 'rejects invalid filters and pages' do
    [{ page: 0 }, { page: 'x' }, { status: 'resolved' }].each do |params|
      get url, params: params, headers: admin.create_new_auth_token
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  it 'exports all matching rows and neutralizes spreadsheet formulas in customer content' do
    conversation.contact.update!(name: '=HYPERLINK("example.com")')
    get "#{url}/export", headers: admin.create_new_auth_token
    expect(response).to have_http_status(:ok)
    rows = CSV.parse(response.body, headers: true)
    expect(rows.size).to eq(1)
    expect(rows.first['Name']).to start_with("'=")
    expect(rows.first['What they want']).to eq('Quote for 200 mugs')

    get "#{url}/export", params: { status: 'won' }, headers: admin.create_new_auth_token
    expect(CSV.parse(response.body, headers: true)).to be_empty
  end

  it 'continues listing old captures without reading private notes' do
    conversation.update!(additional_attributes: { 'business_lead_captured' => true })
    get url, headers: admin.create_new_auth_token
    expect(response.parsed_body['payload'].first).to include('status' => 'new', 'wants' => nil)
  end

  it 'preserves manual progress and the first capture time when lead details are recaptured' do
    assistant = create(:captain_assistant, account: account)
    conversation.update!(additional_attributes: attributes.merge('lead_management' => { 'status' => 'won', 'owner_id' => agent.id }))
    Captain::Leads::DeliveryService.new(assistant, conversation).perform(lead_type: 'wholesale', summary: 'Updated quote', notify: false)

    expect(conversation.reload.additional_attributes).to include(
      'business_lead_captured_at' => '2026-11-15T10:00:00Z', 'lead_management' => { 'status' => 'won', 'owner_id' => agent.id }
    )
    expect(conversation.additional_attributes.dig('captain_summary', 'lead', 'summary')).to eq('Updated quote')
  end
end

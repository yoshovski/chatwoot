require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Captain::McpServers', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:client) { instance_double(Captain::Mcp::Client, list_tools: [{ 'name' => 'refund', 'description' => 'Refund an order' }]) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/captain/mcp_servers" }

  before do
    account.enable_features!('custom_tools')
    allow(Captain::Mcp::Client).to receive(:new).and_return(client)
  end

  it 'connects a server, lists its tools and never returns the token' do
    post base_url, params: { mcp_server: { name: 'Billing', endpoint_url: 'https://example.com/mcp', auth_type: 'bearer', auth_token: 'secret' } },
                   headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    body = response.parsed_body
    expect(body.values_at('status', 'has_auth_token')).to eq(['connected', true])
    expect(body['tools'].pluck('name', 'enabled')).to eq([['refund', false]])
    expect(response.body).not_to include('secret')
  end

  it 'enables tools without listing them again and keeps the saved token' do
    server = account.captain_mcp_servers.create!(name: 'Billing', endpoint_url: 'https://example.com/mcp', auth_type: 'bearer',
                                                 auth_token: 'secret', tools: [{ 'id' => 'mcp1_refund', 'name' => 'refund', 'title' => 'refund',
                                                                                 'description' => '', 'enabled' => false }])

    patch "#{base_url}/#{server.id}", params: { mcp_server: { enabled_tool_names: ['refund'], auth_token: '' } },
                                      headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(server.reload.tools.first['enabled']).to be(true)
    expect(server.auth_token).to eq('secret')
    expect(client).not_to have_received(:list_tools)
  end

  it 'is only available to administrators' do
    get base_url, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end

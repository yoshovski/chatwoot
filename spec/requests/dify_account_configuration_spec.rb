require 'rails_helper'

RSpec.describe 'Dify account configuration', type: :request do
  include_context 'with Dify credential encryption'

  let(:account) { create(:account) }
  let(:super_admin) { create(:super_admin) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:configuration) do
    { base_url: 'https://dify.example.test', knowledge_api_key: 'private-workspace-key',
      embedding_model: 'example-embedding', embedding_model_provider: 'example/provider' }
  end

  it 'lets the platform admin configure a workspace without rendering its stored key' do
    sign_in(super_admin, scope: :super_admin)
    patch "/super_admin/accounts/#{account.id}", params: { account: { dify_configuration: configuration } }

    expect(response).to have_http_status(:redirect)
    expect(account.reload.dify_knowledge_api_key).to eq('private-workspace-key')
    get "/super_admin/accounts/#{account.id}/edit"
    expect(response).to have_http_status(:success)
    expect(response.body).to include('account[dify_configuration][knowledge_api_key]')
    expect(response.body).not_to include('private-workspace-key')
  end

  it 'does not let a client administrator change or read the Dify settings' do
    account.update!(dify_configuration: configuration.stringify_keys)
    patch "/api/v1/accounts/#{account.id}", headers: user.create_new_auth_token,
                                            params: { dify_configuration: configuration.merge(knowledge_api_key: 'replacement'),
                                                      dify_knowledge_api_key: 'replacement' }

    expect(account.reload.dify_knowledge_api_key).to eq('private-workspace-key')
    get "/api/v1/accounts/#{account.id}", headers: user.create_new_auth_token
    expect(response).to have_http_status(:success)
    expect(response.body).not_to include('dify', 'private-workspace-key')
  end
end

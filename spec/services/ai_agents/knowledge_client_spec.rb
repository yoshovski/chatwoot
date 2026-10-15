require 'rails_helper'

RSpec.describe AiAgents::KnowledgeClient do
  let(:account) { create(:account) }
  let(:client) { described_class.new(account: account, actor: create(:user, account: account)) }
  let(:url) { 'http://knowledge.test:8000/v1/knowledge/search' }
  let(:env) { { 'CWAI_SERVICE_URL' => 'http://knowledge.test:8000', 'CWAI_INSTALLATION_ID' => 'test', 'CWAI_SIGNING_KEY' => 'k' * 32 } }

  before { allow(client).to receive(:sleep) }

  it 'retries when the knowledge service refuses the connection' do
    search = stub_request(:post, url).to_raise(Errno::ECONNREFUSED).then.to_return(status: 200, body: '{"passages":[]}')

    with_modified_env(env) do
      response = client.request(method: :post, path: '/v1/knowledge/search', action: 'knowledge:read', payload: { query: 'q' })
      expect(response.code).to eq(200)
    end
    expect(search).to have_been_requested.twice
  end

  it 'gives up after the retries are used' do
    search = stub_request(:post, url).to_raise(Errno::ECONNREFUSED)

    with_modified_env(env) do
      expect { client.request(method: :post, path: '/v1/knowledge/search', action: 'knowledge:read') }.to raise_error(Errno::ECONNREFUSED)
    end
    expect(search).to have_been_requested.times(3)
  end

  it 'does not retry a read timeout because the service may have handled the request' do
    search = stub_request(:post, url).to_raise(Net::ReadTimeout)

    with_modified_env(env) do
      expect { client.request(method: :post, path: '/v1/knowledge/search', action: 'knowledge:read') }.to raise_error(Net::ReadTimeout)
    end
    expect(search).to have_been_requested.once
  end
end

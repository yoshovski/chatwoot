require 'spec_helper'
require 'faraday'
require 'faraday/retry'
require 'active_support/core_ext/object/blank'
require_relative '../../../app/services/shopify_agent_tools/admin_client'

RSpec.describe ShopifyAgentTools::AdminClient do
  let(:api_url) { 'https://shopify-tools.example.com' }
  let(:admin_key) { 'secret_admin_key_123' }
  let(:client) { described_class.new(api_url: api_url, admin_key: admin_key) }

  describe '#initialize' do
    it 'raises error when admin key is blank' do
      expect do
        described_class.new(api_url: api_url, admin_key: nil)
      end.to raise_error(ShopifyAgentTools::AdminClient::Error, /admin key is missing/)
    end
  end

  describe '#create_tenant' do
    it 'posts to v1/admin/tenants and returns parsed JSON' do
      stub_request(:post, "#{api_url}/v1/admin/tenants")
        .with(
          headers: { 'Authorization' => "Bearer #{admin_key}", 'Content-Type' => 'application/json' },
          body: { name: 'Acme', slug: 'acme-store', shop_domain: 'acme.myshopify.com' }.to_json
        )
        .to_return(
          status: 201,
          body: { id: 'sat-123', tool_key: 'sat_tool_key_abc', slug: 'acme-store' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = client.create_tenant(name: 'Acme', slug: 'acme-store', shop_domain: 'acme.myshopify.com')
      expect(result['id']).to eq('sat-123')
      expect(result['tool_key']).to eq('sat_tool_key_abc')
    end
  end

  describe '#configure_shopify' do
    it 'puts to v1/admin/tenants/:id/shopify with custom app credentials' do
      stub_request(:put, "#{api_url}/v1/admin/tenants/sat-123/shopify")
        .with(
          headers: { 'Authorization' => "Bearer #{admin_key}", 'Content-Type' => 'application/json' },
          body: { client_id: 'client_id_x', client_secret: 'client_secret_y', storefront_base_url: 'https://acme.com' }.to_json
        )
        .to_return(
          status: 200,
          body: { install_url: 'https://acme.myshopify.com/admin/oauth/authorize?test=1' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = client.configure_shopify('sat-123', client_id: 'client_id_x', client_secret: 'client_secret_y', storefront_base_url: 'https://acme.com')
      expect(result['install_url']).to include('oauth/authorize')
    end
  end

  describe '#tenant' do
    it 'fetches tenant details' do
      stub_request(:get, "#{api_url}/v1/admin/tenants/sat-123")
        .with(headers: { 'Authorization' => "Bearer #{admin_key}" })
        .to_return(
          status: 200,
          body: { id: 'sat-123', status: 'connected', shopify_connection: { state: 'connected' } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = client.tenant('sat-123')
      expect(result['status']).to eq('connected')
    end
  end

  describe '#rotate_tool_key' do
    it 'rotates tenant tool key' do
      stub_request(:post, "#{api_url}/v1/admin/tenants/sat-123/tool-key/rotate")
        .with(headers: { 'Authorization' => "Bearer #{admin_key}" })
        .to_return(
          status: 200,
          body: { tool_key: 'sat_new_tool_key' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = client.rotate_tool_key('sat-123')
      expect(result['tool_key']).to eq('sat_new_tool_key')
    end
  end

  describe '#delete_tenant' do
    it 'deletes tenant' do
      stub_request(:delete, "#{api_url}/v1/admin/tenants/sat-123")
        .with(headers: { 'Authorization' => "Bearer #{admin_key}" })
        .to_return(status: 204, body: '')

      expect { client.delete_tenant('sat-123') }.not_to raise_error
    end
  end

  describe 'error handling' do
    it 'raises Error with status on HTTP error' do
      stub_request(:get, "#{api_url}/v1/admin/tenants/unknown")
        .to_return(status: 404, body: '{"error":"not found"}')

      expect { client.tenant('unknown') }.to raise_error do |error|
        expect(error).to be_a(ShopifyAgentTools::AdminClient::Error)
        expect(error.status).to eq(404)
      end
    end
  end
end

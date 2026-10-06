# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require_relative '../../../app/services/shopify_agent_tools/client'

RSpec.describe ShopifyAgentTools::Client do
  let(:api_url) { 'https://shopify-tools.example.com' }
  let(:tool_key) { 'test_tool_key_123' }
  let(:client) { described_class.new(tool_key: tool_key, api_url: api_url) }

  describe '#initialize' do
    it 'raises error when tool_key is blank' do
      expect do
        described_class.new(tool_key: '', api_url: api_url)
      end.to raise_error(ShopifyAgentTools::Client::Error, /tool key is missing/)
    end
  end

  describe '#search_products' do
    it 'posts to /v1/tools/shopify/search-products and returns parsed json' do
      stub_request(:post, "#{api_url}/v1/tools/shopify/search-products")
        .with(
          headers: { 'Authorization' => "Bearer #{tool_key}", 'Content-Type' => 'application/json' },
          body: { query: 'drone', limit: 5 }.to_json
        )
        .to_return(
          status: 200,
          body: { products: [{ handle: 'agras-t40', title: 'DJI Agras T40' }] }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = client.search_products(query: 'drone', limit: 5)
      expect(result['products']).to be_an(Array)
      expect(result['products'].first['handle']).to eq('agras-t40')
    end
  end

  describe '#get_product' do
    it 'posts to /v1/tools/shopify/get-product and returns product hash' do
      stub_request(:post, "#{api_url}/v1/tools/shopify/get-product")
        .with(
          headers: { 'Authorization' => "Bearer #{tool_key}", 'Content-Type' => 'application/json' },
          body: { handle: 'agras-t40' }.to_json
        )
        .to_return(
          status: 200,
          body: { id: 'gid://1', handle: 'agras-t40', title: 'DJI Agras T40', available: true }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = client.get_product(handle: 'agras-t40')
      expect(result['handle']).to eq('agras-t40')
      expect(result['available']).to be(true)
    end

    it 'returns nil when product returns 404' do
      stub_request(:post, "#{api_url}/v1/tools/shopify/get-product")
        .with(body: { handle: 'missing-item' }.to_json)
        .to_return(status: 404, body: '{"detail":"Product not found"}')

      result = client.get_product(handle: 'missing-item')
      expect(result).to be_nil
    end
  end

  describe '#browse_catalog' do
    it 'posts to /v1/tools/shopify/browse-catalog and returns collections' do
      stub_request(:post, "#{api_url}/v1/tools/shopify/browse-catalog")
        .with(
          headers: { 'Authorization' => "Bearer #{tool_key}", 'Content-Type' => 'application/json' },
          body: { limit: 10, query: 'drones' }.to_json
        )
        .to_return(
          status: 200,
          body: { collections: [{ handle: 'drones', title: 'Drones', product_count: 5 }] }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = client.browse_catalog(query: 'drones', limit: 10)
      expect(result['collections'].first['handle']).to eq('drones')
    end
  end

  describe '#track_order' do
    it 'posts to /v1/tools/shopify/track-order and returns order tracking result' do
      stub_request(:post, "#{api_url}/v1/tools/shopify/track-order")
        .with(
          headers: { 'Authorization' => "Bearer #{tool_key}", 'Content-Type' => 'application/json' },
          body: { order_number: '#1001', customer_email: 'buyer@example.com' }.to_json
        )
        .to_return(
          status: 200,
          body: { found: true, order_number: '#1001', fulfillment_status: 'fulfilled' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = client.track_order(order_number: '#1001', customer_email: 'buyer@example.com')
      expect(result['found']).to be(true)
      expect(result['order_number']).to eq('#1001')
    end
  end

  describe 'error handling' do
    it 'raises Error on server error' do
      stub_request(:post, "#{api_url}/v1/tools/shopify/search-products")
        .to_return(status: 500, body: '{"detail":"Internal error"}')

      expect { client.search_products(query: 'test') }
        .to raise_error(ShopifyAgentTools::Client::Error) { |error| expect(error.status).to eq(500) }
    end
  end
end

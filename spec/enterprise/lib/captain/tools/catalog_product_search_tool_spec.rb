# frozen_string_literal: true

require 'spec_helper'
require 'active_support/all'
require 'webmock/rspec'

module Captain; end
module Captain::Tools; end
module Captain::Knowledge; end

unless defined?(Captain::Assistant::CITATION_SOURCES_STATE_KEY)
  class Captain::Assistant
    CITATION_SOURCES_STATE_KEY = :captain_v2_citation_sources
    CITATION_DETAILS_STATE_KEY = :captain_v2_citation_details
    PRODUCT_HANDLES_STATE_KEY = :captain_v2_product_handles
  end
end

require_relative '../../../../../enterprise/lib/captain/tools/base_public_tool'
require_relative '../../../../../enterprise/lib/captain/tools/shopify_tool_helpers'
require_relative '../../../../../enterprise/lib/captain/tools/catalog_product_search_tool'
require_relative '../../../../../enterprise/app/services/captain/knowledge/search'

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe Captain::Tools::CatalogProductSearchTool do
  let(:account_custom_attributes) { {} }
  let(:account_name) { 'Standard Store' }
  let(:account) do
    double(
      'Account',
      id: 1,
      name: account_name,
      custom_attributes: account_custom_attributes,
      hooks: hooks_relation,
      feature_enabled?: true
    )
  end
  let(:hooks_relation) { double('hooks_relation') }
  let(:assistant_config) { { 'feature_citation' => true } }
  let(:assistant) do
    double(
      'Captain::Assistant',
      account: account,
      account_id: 1,
      config: assistant_config,
      citations_enabled?: true,
      shopify_tools_available?: true
    )
  end
  let(:tool) { described_class.new(assistant) }
  let(:tool_context) { Struct.new(:state).new({}) }
  let(:hook_settings) do
    {
      'state' => 'connected',
      'encrypted_tool_key' => 'sat_tool_key_123',
      'catalog_dataset_id' => 'ds-catalog-1',
      'catalog_sync_enabled' => true
    }
  end
  let(:hook) do
    double(
      'Integrations::Hook',
      app_id: 'shopify',
      shopify?: true,
      shopify_connected?: true,
      shopify_tool_key: 'sat_tool_key_123',
      shopify_sat_client: sat_client,
      reference_id: 'test-store.myshopify.com',
      settings: hook_settings
    )
  end
  let(:sat_client) { double('ShopifyAgentTools::Client') }

  before do
    allow(hooks_relation).to receive(:find_by).with(app_id: 'shopify').and_return(hook)
    allow(tool).to receive(:log_tool_usage)
  end

  describe '#description and #parameters' do
    it 'has description and expected params' do
      expect(tool.description).to include('Search active products in the Shopify catalog')
      expect(tool.parameters).to have_key(:query)
      expect(tool.parameters).to have_key(:limit)
    end
  end

  describe '#active?' do
    it 'returns true when Shopify tools are available' do
      expect(tool.active?).to be true
    end

    it 'returns false when assistant reports tools not available' do
      allow(assistant).to receive(:shopify_tools_available?).and_return(false)
      expect(tool.active?).to be false
    end
  end

  describe '#perform' do
    let(:knowledge_search) { double('Captain::Knowledge::Search') }
    let(:product_hit) do
      {
        'id' => 'gid://shopify/Product/1',
        'handle' => 'agras-t40',
        'title' => 'DJI Agras T40 Spraying Drone',
        'description' => 'Flagship agricultural spraying drone',
        'product_url' => 'https://test-store.myshopify.com/products/agras-t40',
        'image_url' => 'https://cdn.shopify.com/t40.jpg',
        'available' => true,
        'variants' => [
          { 'id' => 'v1', 'title' => 'Standard', 'sku' => 'T40-STD', 'price' => '19999.00', 'currency' => 'EUR', 'available' => true }
        ]
      }
    end

    before do
      allow(Captain::Knowledge::Search).to receive(:new).with(assistant).and_return(knowledge_search)
      allow(sat_client).to receive(:search_products).and_return({ 'products' => [] })
      allow(sat_client).to receive(:get_product).with(handle: 'agras-t40').and_return(product_hit)
    end

    it 'finds products through semantic knowledge search and fetches live product data' do
      passage = Captain::Knowledge::Search::Passage.new(
        kind: 'catalog',
        title: 'DJI Agras T40',
        content: "Product handle: agras-t40\nSpraying drone for fields",
        score: 0.92,
        handle: 'agras-t40',
        dataset_id: 'ds-catalog-1'
      )
      allow(knowledge_search).to receive(:search).with('spraying drone', kinds: %w[catalog product]).and_return([passage])

      result = tool.perform(tool_context, query: 'spraying drone')

      expect(result).to include('DJI Agras T40 Spraying Drone')
      expect(result).to include('19999.00 EUR')
      expect(result).to include('https://test-store.myshopify.com/products/agras-t40')
      expect(result).to include('Citation index: 1')

      # Handles recorded in state
      expect(tool_context.state[:product_handles]).to include('agras-t40')
      expect(tool_context.state[Captain::Assistant::PRODUCT_HANDLES_STATE_KEY]).to include('agras-t40')
    end

    it 'prioritizes exact matches from SAT search_products' do
      allow(sat_client).to receive(:search_products).with(query: 'agras-t40', limit: 5).and_return(
        { 'products' => [{ 'handle' => 'agras-t40', 'title' => 'DJI Agras T40' }] }
      )
      allow(knowledge_search).to receive(:search).and_return([])

      result = tool.perform(tool_context, query: 'agras-t40')
      expect(result).to include('DJI Agras T40 Spraying Drone')
      expect(tool_context.state[:product_handles]).to eq(['agras-t40'])
    end

    context 'when hide_stock is enabled in hook settings' do
      let(:hook_settings) do
        {
          'state' => 'connected',
          'encrypted_tool_key' => 'sat_tool_key_123',
          'hide_stock' => true
        }
      end

      before do
        allow(sat_client).to receive(:search_products).and_return(
          { 'products' => [{ 'handle' => 'agras-t40' }] }
        )
        allow(knowledge_search).to receive(:search).and_return([])
      end

      it 'removes availability and stock indicators from results' do
        result = tool.perform(tool_context, query: 'agras-t40')

        expect(result).not_to include('Available:')
        expect(result).not_to include('[Available: true]')
        expect(result).to include('DJI Agras T40 Spraying Drone')
      end
    end

    context 'when account name contains scanixx' do
      let(:account_name) { 'Scanixx Store' }

      before do
        allow(sat_client).to receive(:search_products).and_return(
          { 'products' => [{ 'handle' => 'agras-t40' }] }
        )
        allow(knowledge_search).to receive(:search).and_return([])
      end

      it 'automatically enforces hide stock for Scanixx' do
        result = tool.perform(tool_context, query: 'agras-t40')
        expect(result).not_to include('Available:')
      end
    end

    context 'when product is not found or fails to fetch' do
      it 'keeps product marked unavailable on error' do
        allow(sat_client).to receive(:search_products).and_return(
          { 'products' => [{ 'handle' => 'broken-item' }] }
        )
        allow(knowledge_search).to receive(:search).and_return([])
        allow(sat_client).to receive(:get_product).with(handle: 'broken-item').and_raise(StandardError, 'Network timeout')

        result = tool.perform(tool_context, query: 'broken-item')
        expect(result).to include('Broken Item')
        expect(tool_context.state[:product_handles]).to include('broken-item')
      end
    end

    context 'when connection is disconnected' do
      before do
        allow(assistant).to receive(:shopify_tools_available?).and_return(false)
      end

      it 'returns error message' do
        result = tool.perform(tool_context, query: 'drone')
        expect(result).to include('Shopify is not connected for this account')
      end
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles

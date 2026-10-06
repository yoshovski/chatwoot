# frozen_string_literal: true

require 'spec_helper'
require 'active_support/all'

module Captain; end
module Captain::Tools; end

unless defined?(Captain::Assistant::PRODUCT_HANDLES_STATE_KEY)
  class Captain::Assistant
    PRODUCT_HANDLES_STATE_KEY = :captain_v2_product_handles
  end
end

require_relative '../../../../../enterprise/lib/captain/tools/base_public_tool'
require_relative '../../../../../enterprise/lib/captain/tools/shopify_tool_helpers'
require_relative '../../../../../enterprise/lib/captain/tools/browse_catalog_tool'

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe Captain::Tools::BrowseCatalogTool do
  let(:account) do
    double(
      'Account',
      id: 1,
      name: 'Test Store',
      custom_attributes: {},
      hooks: hooks_relation,
      feature_enabled?: true
    )
  end
  let(:hooks_relation) { double('hooks_relation') }
  let(:assistant) do
    double(
      'Captain::Assistant',
      account: account,
      account_id: 1,
      config: {},
      citations_enabled?: false,
      shopify_tools_available?: true
    )
  end
  let(:tool) { described_class.new(assistant) }
  let(:tool_context) { Struct.new(:state).new({}) }
  let(:hook) do
    double(
      'Integrations::Hook',
      app_id: 'shopify',
      shopify?: true,
      shopify_connected?: true,
      shopify_tool_key: 'sat_key',
      shopify_sat_client: sat_client,
      reference_id: 'test.myshopify.com',
      settings: { 'state' => 'connected' }
    )
  end
  let(:sat_client) { double('ShopifyAgentTools::Client') }

  before do
    allow(hooks_relation).to receive(:find_by).with(app_id: 'shopify').and_return(hook)
    allow(tool).to receive(:log_tool_usage)
  end

  describe '#description and #parameters' do
    it 'has description and expected params' do
      expect(tool.description).to include('Browse Shopify product collections')
      expect(tool.parameters).to have_key(:query)
      expect(tool.parameters).to have_key(:limit)
    end
  end

  describe '#active?' do
    it 'returns true when shopify tools are available' do
      expect(tool.active?).to be true
    end

    it 'returns false when shopify tools are not available' do
      allow(assistant).to receive(:shopify_tools_available?).and_return(false)
      expect(tool.active?).to be false
    end
  end

  describe '#perform' do
    it 'browses collections and records collection handles' do
      allow(sat_client).to receive(:browse_catalog).with(query: 'drones', limit: 10).and_return(
        {
          'collections' => [
            {
              'id' => 'gid://shopify/Collection/1',
              'title' => 'Agricultural Drones',
              'handle' => 'agricultural-drones',
              'description' => 'Professional sprayers and seeders',
              'collection_url' => 'https://test.myshopify.com/collections/agricultural-drones',
              'product_count' => 8
            }
          ]
        }
      )

      result = tool.perform(tool_context, query: 'drones')

      expect(result).to include('Collection: Agricultural Drones')
      expect(result).to include('Handle: agricultural-drones')
      expect(result).to include('https://test.myshopify.com/collections/agricultural-drones')
      expect(result).to include('Product count: 8')

      expect(tool_context.state[:product_handles]).to include('agricultural-drones')
    end

    it 'returns friendly message when no collections found' do
      allow(sat_client).to receive(:browse_catalog).and_return({ 'collections' => [] })

      result = tool.perform(tool_context)
      expect(result).to eq('No collections found in catalog.')
    end

    it 'returns failure result when connection is not available' do
      allow(assistant).to receive(:shopify_tools_available?).and_return(false)

      result = tool.perform(tool_context)
      expect(result).to include('Shopify is not connected for this account')
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles

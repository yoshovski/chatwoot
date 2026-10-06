# frozen_string_literal: true

require 'spec_helper'
require 'active_support/all'

module Captain; end
module Captain::Tools; end
module Captain::Knowledge; end
module Concerns; end

require_relative '../../../../enterprise/lib/captain/tools/base_public_tool'
require_relative '../../../../enterprise/lib/captain/tools/shopify_tool_helpers'
require_relative '../../../../enterprise/lib/captain/tools/catalog_product_search_tool'
require_relative '../../../../enterprise/lib/captain/tools/browse_catalog_tool'
require_relative '../../../../enterprise/lib/captain/tools/track_order_tool'
require_relative '../../../../enterprise/lib/captain/tools/faq_lookup_tool'
require_relative '../../../../enterprise/lib/captain/tools/handoff_tool'
require_relative '../../../../enterprise/app/services/captain/knowledge/citation_sources'

class AssistantShopifyTestWrapper
  CITATION_SOURCES_STATE_KEY = :captain_v2_citation_sources
  CITATION_DETAILS_STATE_KEY = :captain_v2_citation_details
  PRODUCT_HANDLES_STATE_KEY = :captain_v2_product_handles
  SHOPIFY_TOOL_IDS = %w[catalog_product_search browse_catalog track_order].freeze

  attr_accessor :account, :config

  def initialize(account, config = {})
    @account = account
    @config = config
  end

  def self.resolve_tool_class(tool_id)
    "Captain::Tools::#{tool_id.classify}Tool".safe_constantize
  end

  def self.built_in_agent_tools
    [
      { id: 'faq_lookup', title: 'FAQ Lookup' },
      { id: 'handoff', title: 'Handoff' },
      { id: 'catalog_product_search', title: 'Search Products' },
      { id: 'browse_catalog', title: 'Browse Catalog' },
      { id: 'track_order', title: 'Track Order' }
    ]
  end

  def shopify_tools_available?
    hook = account.hooks.find_by(app_id: 'shopify')
    return false unless hook&.shopify_connected? && hook.shopify_tool_key.present?

    hook.shopify_catalog_client_status == 'on'
  end

  def available_agent_tools
    tools = self.class.built_in_agent_tools.dup
    tools.reject! { |tool| SHOPIFY_TOOL_IDS.include?(tool[:id]) } unless shopify_tools_available?

    custom_tools = account.captain_custom_tools.enabled.map(&:to_tool_metadata)
    tools.concat(custom_tools)

    tools
  end

  def agent_tools
    tools = [
      self.class.resolve_tool_class('faq_lookup').new(self),
      self.class.resolve_tool_class('handoff').new(self)
    ]

    if shopify_tools_available?
      tools << self.class.resolve_tool_class('catalog_product_search').new(self)
      tools << self.class.resolve_tool_class('browse_catalog').new(self)
      tools << self.class.resolve_tool_class('track_order').new(self)
    end

    tools
  end
end

# rubocop:disable RSpec/DescribeClass, RSpec/VerifiedDoubles
RSpec.describe 'Captain::Assistant Shopify tools integration' do
  let(:account) do
    double(
      'Account',
      id: 1,
      name: 'Store',
      custom_attributes: {},
      hooks: hooks_relation,
      captain_custom_tools: double('CustomTools', enabled: [])
    )
  end
  let(:hooks_relation) { double('hooks_relation') }
  let(:hook) do
    double(
      'Integrations::Hook',
      app_id: 'shopify',
      shopify?: true,
      shopify_connected?: true,
      shopify_tool_key: 'sat_key_123',
      shopify_catalog_client_status: 'on'
    )
  end
  let(:assistant) { AssistantShopifyTestWrapper.new(account, { 'feature_citation' => true }) }

  before do
    allow(hooks_relation).to receive(:find_by).with(app_id: 'shopify').and_return(hook)
  end

  context 'when Shopify connection is on' do
    it 'reports shopify_tools_available? true' do
      expect(assistant.shopify_tools_available?).to be true
    end

    it 'includes shopify tools in available_agent_tools' do
      tool_ids = assistant.available_agent_tools.map { |t| t[:id] }
      expect(tool_ids).to include('catalog_product_search', 'browse_catalog', 'track_order')
    end

    it 'instantiates shopify tools in agent_tools' do
      tools = assistant.agent_tools
      expect(tools.map(&:class)).to include(
        Captain::Tools::CatalogProductSearchTool,
        Captain::Tools::BrowseCatalogTool,
        Captain::Tools::TrackOrderTool
      )
    end
  end

  context 'when Shopify connection is not on' do
    before do
      allow(hook).to receive(:shopify_catalog_client_status).and_return('off')
    end

    it 'reports shopify_tools_available? false' do
      expect(assistant.shopify_tools_available?).to be false
    end

    it 'excludes shopify tools from available_agent_tools' do
      tool_ids = assistant.available_agent_tools.map { |t| t[:id] }
      expect(tool_ids).not_to include('catalog_product_search', 'browse_catalog', 'track_order')
    end

    it 'does not instantiate shopify tools in agent_tools' do
      tools = assistant.agent_tools
      expect(tools.map(&:class)).not_to include(
        Captain::Tools::CatalogProductSearchTool,
        Captain::Tools::BrowseCatalogTool,
        Captain::Tools::TrackOrderTool
      )
    end
  end
end
# rubocop:enable RSpec/DescribeClass, RSpec/VerifiedDoubles

require 'rails_helper'

RSpec.describe Captain::Assistant do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:settings) { { 'state' => 'connected', 'catalog_dataset_id' => 'dataset-1' } }
  let(:catalog_tool_ids) { %w[catalog_product_search browse_catalog] }
  let(:agent_tool_classes) { assistant.agent_tools.map(&:class) }

  before do
    hook = build(:integrations_hook, :shopify, account: account, settings: settings)
    hook.shopify_tool_key = 'sat_key_123'
    hook.save!
  end

  context 'when the store is connected and the catalog is synced' do
    it 'offers the catalog tools and order tracking' do
      expect(assistant.available_tool_ids).to include(*catalog_tool_ids, 'track_order')
      expect(agent_tool_classes).to include(Captain::Tools::CatalogProductSearchTool, Captain::Tools::BrowseCatalogTool,
                                            Captain::Tools::TrackOrderTool)
    end
  end

  context 'when the catalog sync is paused' do
    let(:settings) { { 'state' => 'connected', 'catalog_dataset_id' => 'dataset-1', 'catalog_sync_enabled' => false } }

    it 'keeps order tracking and drops the catalog tools' do
      expect(assistant.available_tool_ids).to include('track_order')
      expect(assistant.available_tool_ids).not_to include(*catalog_tool_ids)
      expect(agent_tool_classes).to include(Captain::Tools::TrackOrderTool)
      expect(agent_tool_classes).not_to include(Captain::Tools::CatalogProductSearchTool, Captain::Tools::BrowseCatalogTool)
    end
  end

  context 'when the catalog is still importing' do
    let(:settings) { { 'state' => 'connected' } }

    it 'keeps order tracking and drops the catalog tools' do
      expect(assistant.available_tool_ids).to include('track_order')
      expect(assistant.available_tool_ids).not_to include(*catalog_tool_ids)
    end
  end

  context 'when the store is not connected yet' do
    let(:settings) { { 'state' => 'requested' } }

    it 'offers no Shopify tools' do
      expect(assistant.available_tool_ids).not_to include(*catalog_tool_ids, 'track_order')
      expect(agent_tool_classes).not_to include(Captain::Tools::TrackOrderTool)
    end
  end
end

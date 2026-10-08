# frozen_string_literal: true

class Captain::Tools::BrowseCatalogTool < Captain::Tools::BasePublicTool
  include Captain::Tools::ShopifyToolHelpers

  description 'Browse Shopify product collections and categories in the store catalog'
  param :query, type: 'string', desc: 'Optional collection or category name to search for (e.g. accessories)', required: false
  param :limit, type: 'integer', desc: 'Maximum number of collections to return (default: 10, max: 20)', required: false

  def perform(tool_context, query: nil, limit: 10)
    client = shopify_sat_client
    unless client && @assistant.shopify_catalog_tools_available?
      return failure_result('Shopify is not connected for this account', tool_context.state)
    end

    log_tool_usage('browsing_catalog', { query: query })
    collections = fetch_collections(client, query, limit)
    return no_matching_collection(tool_context, client, query, limit) if collections.empty?

    process_collections(tool_context, query, collections)
  rescue ShopifyAgentTools::Client::Error => e
    Rails.logger.warn("SAT browse_catalog failed: #{e.message}") if defined?(Rails) && Rails.respond_to?(:logger)
    failure_result("Failed to browse catalog: #{e.message}", tool_context.state)
  end

  def active?
    @assistant.shopify_catalog_tools_available?
  end

  private

  def safe_to_run_after_new_customer_message?
    true
  end

  # A category without its own collection is not a dead end: list the collections the store has instead.
  def no_matching_collection(tool_context, client, query, limit)
    collections = query.present? ? fetch_collections(client, nil, limit) : []
    return 'No collections found in catalog.' if collections.empty?

    "No collection matches \"#{query}\". The store's collections are:\n#{process_collections(tool_context, nil, collections)}"
  end

  def fetch_collections(client, query, limit)
    result = client.browse_catalog(query: query.presence, limit: normalize_limit(limit))
    result&.dig('collections') || []
  end

  def process_collections(tool_context, query, collections)
    record_product_handles(tool_context, collections.filter_map { |c| c['handle'] })
    log_tool_usage('found_collections', { query: query, count: collections.size })
    format_collections(collections)
  end

  def normalize_limit(limit)
    limit_val = limit.presence&.to_i || 10
    limit_val = 10 if limit_val < 1
    [limit_val, 20].min
  end

  def format_collections(collections)
    collections.map do |col|
      lines = ["Collection: #{col['title']}"]
      lines << "Handle: #{col['handle']}" if col['handle'].present?
      lines << "Description: #{col['description']}" if col['description'].present?
      lines << "URL: #{col['collection_url']}" if col['collection_url'].present?
      lines << "Product count: #{col['product_count']}" if col['product_count'].present?
      lines.join("\n")
    end.join("\n\n---\n\n")
  end
end

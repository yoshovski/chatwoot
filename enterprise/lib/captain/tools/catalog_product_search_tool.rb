# frozen_string_literal: true

class Captain::Tools::CatalogProductSearchTool < Captain::Tools::BasePublicTool
  include Captain::Tools::ShopifyToolHelpers
  include Captain::Tools::SourceIndexing

  description 'Search active products in the Shopify catalog for product discovery, recommendations, live prices and links, or "do you sell X". ' \
              'Keep exact variants in the query; ask for at most 3 products.'
  param :query, type: 'string', desc: 'The product name, SKU or a few key words, such as "a phone case" or "model X200 battery"'
  param :limit, type: 'integer', desc: 'Maximum number of products to return (default: 3, at most 10)', required: false

  def perform(tool_context, query:, limit: 3)
    client = shopify_sat_client
    unless client && @assistant.shopify_catalog_tools_available?
      return failure_result('Shopify is not connected for this account', tool_context.state)
    end

    log_tool_usage('searching_products', { query: query })
    selected_handles = resolve_search_handles(query, limit)
    if selected_handles.empty?
      record_product_search_stats(tool_context, 0)
      return "No products found matching: #{query}"
    end

    cached_products = tool_context&.state&.dig(Captain::Assistant::PRODUCT_CACHE_STATE_KEY) || {}
    products = fetch_live_products(client, selected_handles, cached: cached_products)
    record_product_search_stats(tool_context, active_products_count(products))
    process_found_products(tool_context, query, products)
  end

  def active?
    @assistant.shopify_catalog_tools_available?
  end

  private

  def safe_to_run_after_new_customer_message?
    true
  end

  def resolve_search_handles(query, limit)
    semantic_matches = fetch_semantic_matches(query)
    all_handles = semantic_matches.map(&:to_s).map(&:strip).reject(&:blank?).uniq(&:downcase)
    all_handles.take(normalize_limit(limit))
  end

  def process_found_products(tool_context, query, products)
    products.each { |product| sanitize_product_stock!(product) }
    returned_handles = products.filter_map { |product| product['handle'] }
    record_product_handles(tool_context, returned_handles)
    cache_products(tool_context, products)
    log_tool_usage('found_products', { query: query, count: products.size, handles: returned_handles })
    format_products(tool_context, products)
  end

  def record_product_search_stats(tool_context, count)
    return if tool_context&.state.nil?

    stats = tool_context.state[Captain::Assistant::PRODUCT_SEARCH_STATS_STATE_KEY] ||= { searches: 0, results: 0 }
    stats[:searches] += 1
    stats[:results] += count
    tool_context.state[Captain::Assistant::PRODUCT_SEARCH_STATS_STATE_KEY] = stats
  end

  def active_products_count(products)
    products.count { |p| p['handle'].present? && p['available'] != false }
  end

  def normalize_limit(limit)
    limit_val = limit.presence&.to_i || 3
    limit_val = 3 if limit_val < 1
    [limit_val, 10].min
  end

  def fetch_semantic_matches(query)
    passages = Captain::Knowledge::Search.new(@assistant).search(query, kinds: %w[catalog product])
    passages.filter_map { |passage| extract_handle(passage) }
  rescue StandardError => e
    Rails.logger.warn("Captain knowledge search failed during catalog search: #{e.message}") if defined?(Rails) && Rails.respond_to?(:logger)
    []
  end

  def extract_handle(passage)
    handle_from_attributes(passage) || handle_from_content(passage) || handle_from_title(passage)
  end

  def handle_from_attributes(passage)
    handle = passage.handle if passage.respond_to?(:handle)
    if handle.blank? && passage.respond_to?(:metadata) && passage.metadata.is_a?(Hash)
      handle = passage.metadata['handle'] || passage.metadata['product_handle']
    end
    handle.to_s.strip.downcase.presence
  end

  def handle_from_content(passage)
    content = passage.respond_to?(:content) ? passage.content.to_s : ''
    match = content.match(/^\s*(?:-\s*)?Product handle:\s*([a-z0-9][a-z0-9_-]*)\s*$/i)
    match ? match[1].strip.downcase : nil
  end

  def handle_from_title(passage)
    title = passage.respond_to?(:title) ? passage.title.to_s : ''
    cleaned = title.sub(/\.(md|txt|json|html?|pdf|docx?|csv)\z/i, '').strip
    cleaned.downcase if cleaned.present? && cleaned.exclude?(' ')
  end

  # Live lookups reuse cached products, hydrating missing details in parallel.
  def fetch_live_products(client, handles, cached: {})
    needed = handles.reject { |h| product_complete?(cached[h]) }
    loaded_map = needed.zip(await(needed.map { |h| in_background { fetch_single_product(client, h) } })).to_h

    handles.map { |h| resolve_live_product(h, cached[h], loaded_map[h]) }
  end

  def resolve_live_product(handle, cached, loaded)
    return cached if product_complete?(cached)

    loaded || unavailable_stub(handle)
  end

  def product_complete?(product)
    product.is_a?(Hash) && product['variants'].is_a?(Array) && product['variants'].any?
  end

  # For HTTP-only work. Waiting permits concurrent loads so a background thread can autoload code without deadlocking.
  def in_background(&)
    if defined?(Rails) && Rails.respond_to?(:application) && Rails.application.respond_to?(:executor)
      Thread.new { Rails.application.executor.wrap(&) }
    else
      Thread.new(&)
    end
  end

  def await(threads)
    if defined?(ActiveSupport::Dependencies) && ActiveSupport::Dependencies.respond_to?(:interlock)
      ActiveSupport::Dependencies.interlock.permit_concurrent_loads { threads.map(&:value) }
    else
      threads.map(&:value)
    end
  end

  def fetch_single_product(client, handle)
    client.get_product(handle: handle) || unavailable_stub(handle)
  rescue StandardError => e
    Rails.logger.warn("Failed to get product #{handle}: #{e.message}") if defined?(Rails) && Rails.respond_to?(:logger)
    unavailable_stub(handle)
  end

  def unavailable_stub(handle)
    {
      'handle' => handle,
      'title' => handle.tr('-_', ' ').titleize,
      'available' => false,
      'variants' => []
    }
  end

  def format_products(tool_context, products)
    products.map do |product|
      format_single_product(tool_context, product)
    end.join("\n\n---\n\n")
  end

  def format_single_product(tool_context, product)
    lines = build_product_lines(product)
    append_availability_and_variants!(lines, product)
    append_source_index!(tool_context, lines, product)
    lines.join("\n")
  end

  def build_product_lines(product)
    lines = ["Product: #{product['title']}"]
    lines << "Handle: #{product['handle']}" if product['handle'].present?
    lines << "Description: #{product['description']}" if product['description'].present?
    lines << "Product URL: #{product['product_url']}" if product['product_url'].present?
    lines << "Image URL: #{product['image_url']}" if product['image_url'].present?
    lines
  end

  def append_source_index!(tool_context, lines, product)
    return if product['handle'].blank?

    detail = { kind: 'product', title: product['title'], excerpt: source_excerpt(product['description']), url: product['product_url'] }
    lines << "Source index: #{source_index_for(tool_context, "product:#{product['handle']}", detail)}"
  end

  def append_availability_and_variants!(lines, product)
    lines << "Available: #{product['available']}" if !hide_stock? && product.key?('available')

    variants = product['variants']
    if variants.present?
      variant_lines = variants.map { |v| format_variant(v) }
      lines << "Variants:\n#{variant_lines.join("\n")}"
    elsif product['price'].present?
      lines << "Price: #{product['price']}"
    end
  end

  def format_variant(variant)
    info = "  - #{variant['title']}: #{variant['price']} #{variant['currency']}"
    info += " (SKU: #{variant['sku']})" if variant['sku'].present?
    info += " [Available: #{variant['available']}]" if !hide_stock? && variant.key?('available')
    info
  end
end

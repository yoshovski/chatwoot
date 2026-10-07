# frozen_string_literal: true

class Captain::Tools::CatalogProductSearchTool < Captain::Tools::BasePublicTool
  include Captain::Tools::ShopifyToolHelpers
  include Captain::Tools::SourceIndexing

  description 'Search active products in the Shopify catalog with live prices, variants and links'
  param :query, type: 'string', desc: 'The product name, SKU or a few key words, such as "DB2160" or "Agras T100 battery"'
  param :limit, type: 'integer', desc: 'Maximum number of products to return (default: 3, at most 10)', required: false

  def perform(tool_context, query:, limit: 3)
    client = shopify_sat_client
    return failure_result('Shopify is not connected for this account', tool_context.state) unless client && @assistant.shopify_tools_available?

    log_tool_usage('searching_products', { query: query })
    selected_handles = resolve_search_handles(client, query, limit)
    return "No products found matching: #{query}" if selected_handles.empty?

    products = fetch_live_products(client, selected_handles)
    process_found_products(tool_context, query, products)
  end

  def active?
    @assistant.shopify_tools_available?
  end

  private

  def safe_to_run_after_new_customer_message?
    true
  end

  # The Shopify search runs in the background while the knowledge search uses this thread's database connection.
  def resolve_search_handles(client, query, limit)
    exact_matches = in_background { fetch_exact_matches(client, query) }
    semantic_matches = fetch_semantic_matches(query)
    all_handles = (await([exact_matches]).first + semantic_matches)
                  .map(&:to_s).map(&:strip).reject(&:blank?).uniq(&:downcase)
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

  def normalize_limit(limit)
    limit_val = limit.presence&.to_i || 3
    limit_val = 3 if limit_val < 1
    [limit_val, 10].min
  end

  def fetch_exact_matches(client, query)
    res = client.search_products(query: query, limit: 5)
    return [] unless res && res['products'].is_a?(Array)

    res['products'].filter_map { |p| p['handle'] }
  rescue StandardError => e
    Rails.logger.warn("SAT search_products failed during catalog search: #{e.message}") if defined?(Rails) && Rails.respond_to?(:logger)
    []
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
    match = content.match(/^\s*Product handle:\s*([a-z0-9][a-z0-9_-]*)\s*$/i)
    match ? match[1].strip.downcase : nil
  end

  def handle_from_title(passage)
    title = passage.respond_to?(:title) ? passage.title.to_s : ''
    cleaned = title.sub(/\.(md|txt|json|html?|pdf|docx?|csv)\z/i, '').strip
    cleaned.downcase if cleaned.present? && cleaned.exclude?(' ')
  end

  # Live lookups are independent HTTP calls, so they run in parallel (at most 10, the search limit).
  def fetch_live_products(client, handles)
    await(handles.map { |handle| in_background { fetch_single_product(client, handle) } })
  end

  # For HTTP-only work. Waiting permits concurrent loads so a background thread can autoload code without deadlocking.
  def in_background(&)
    Thread.new { Rails.application.executor.wrap(&) }
  end

  def await(threads)
    ActiveSupport::Dependencies.interlock.permit_concurrent_loads { threads.map(&:value) }
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

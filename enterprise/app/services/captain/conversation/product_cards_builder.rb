# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class Captain::Conversation::ProductCardsBuilder
  include Captain::Tools::ShopifyToolHelpers

  MAX_CARDS = 10
  MAX_TITLE_LENGTH = 80
  MAX_DESCRIPTION_LENGTH = 200
  # Products shown as cards within this many recent messages are not shown again.
  RECENT_MESSAGES = 10
  STOCK_PHRASE_REGEX =
    /\b(?:in\s+stock(?:\s+now)?|out\s+of\s+stock|sold\s+out|available\s+now|ready\s+to\s+ship|only\s+\d+\s+left|\d+\s+in\s+stock)\b/i

  attr_reader :assistant, :conversation, :response, :run_result

  def initialize(assistant:, response:, run_result:, conversation: nil)
    @assistant = assistant
    @conversation = conversation
    @response = response
    @run_result = run_result
    @resolved = false
  end

  def products?
    resolve_products!
    cards_items.any? || article_items.any?
  end
  alias has_products? products?

  def cards_items
    resolve_products!
    @cards_items
  end

  def article_items
    resolve_products!
    @article_items
  end

  def shown_handles
    resolve_products!
    @shown_handles
  end

  def all_shown_product_urls
    resolve_products!
    @shown_product_urls
  end

  def filter_citation_urls(citation_urls)
    return {} if citation_urls.blank?
    return citation_urls unless citation_urls.is_a?(Hash)

    urls = sanitizer.filter_citation_urls(citation_urls)
    return urls unless products?

    shown_urls = all_shown_product_urls
    handles_patterns = shown_handles.map { |h| "/products/#{h.downcase}" }

    urls.reject do |_idx, url|
      citation_matches_product?(url, shown_urls, handles_patterns)
    end
  end

  def clean_prose_content(content)
    text = content.dup
    text = strip_product_urls(text) if products?
    text = sanitizer.sanitize_prose(text)

    if products? && text.blank?
      fallback_prose_text
    else
      text
    end
  end

  def build_messages(agent_name: nil)
    return [] unless products?

    additional_attrs = agent_name.present? ? { agent_name: agent_name } : {}
    messages = []
    messages << build_message('cards', cards_items, additional_attrs) if cards_items.any?
    messages << build_message('article', article_items, additional_attrs) if article_items.any?
    messages
  end

  def post_messages!(preserve_waiting_since: false, agent_name: nil)
    build_messages(agent_name: agent_name).map do |payload|
      @conversation.messages.create!(
        payload.merge(
          message_type: :outgoing,
          account_id: @assistant.account_id,
          inbox_id: @conversation.inbox_id,
          sender: @assistant,
          preserve_waiting_since: preserve_waiting_since
        )
      )
    end
  end

  private

  def citation_matches_product?(url, shown_urls, handles_patterns)
    url_str = url.to_s.downcase
    shown_urls.any? { |su| su.casecmp?(url.to_s) } || handles_patterns.any? { |pat| url_str.include?(pat) }
  end

  def strip_product_urls(text)
    all_shown_product_urls.compact_blank.each do |url|
      escaped = Regexp.escape(url)
      text = text.gsub(/\[([^\]]+)\]\(#{escaped}\)/, '\1').gsub(/<?#{escaped}>?/, '')
    end

    shown_handles.compact_blank.each do |handle|
      pattern = %r{https?://[^/\s\)]+/products/#{Regexp.escape(handle)}}i
      text = text.gsub(/\[([^\]]+)\]\(#{pattern}\)/, '\1').gsub(/<?#{pattern}>?/, '')
    end

    text
  end

  def fallback_prose_text
    shown_handles.size > 1 ? 'Here are the recommended products:' : 'Here is the product:'
  end

  def build_message(content_type, items, additional_attrs)
    {
      content: items.first['title'],
      content_type: content_type,
      content_attributes: { items: items.take(MAX_CARDS) },
      additional_attributes: additional_attrs.merge(product_handles: shown_handles)
    }
  end

  def resolve_products!
    return if @resolved

    @resolved = true
    @cards_items = []
    @article_items = []
    @shown_handles = []
    @shown_product_urls = []

    valid_handles = extract_valid_handles
    return if valid_handles.blank?

    build_items_for_handles(valid_handles)
  end

  def extract_valid_handles
    return [] unless @assistant.product_cards?

    raw_handles = raw_response_handles
    allowed_handles = allowed_run_handles
    return [] if raw_handles.blank? || allowed_handles.blank?

    recent_handles = recently_shown_handles
    filter_matching_handles(raw_handles, allowed_handles).reject do |handle|
      recent_handles.any? { |recent| recent.casecmp?(handle) }
    end
  end

  def recently_shown_handles
    return [] unless @conversation

    recent_ids = @conversation.messages.reorder(id: :desc).limit(RECENT_MESSAGES).select(:id)
    @conversation.messages.where(id: recent_ids, content_type: %w[cards article])
                 .pluck(:additional_attributes)
                 .flat_map { |attributes| Array(attributes&.dig('product_handles')) }
  end

  def raw_response_handles
    raw = @response.is_a?(Hash) ? @response['product_handles'] : nil
    Array(raw).map(&:to_s).map(&:strip).reject(&:blank?)
  end

  def allowed_run_handles
    Array(@assistant.run_result_product_handles(@run_result)).map(&:to_s).map(&:strip).reject(&:blank?)
  end

  def filter_matching_handles(raw_handles, allowed_handles)
    raw_handles.select do |handle|
      allowed_handles.any? { |ah| ah.casecmp?(handle) }
    end.uniq(&:downcase).take(MAX_CARDS)
  end

  def build_items_for_handles(handles)
    client = shopify_sat_client
    cached_products = load_cached_products

    handles.each do |handle|
      process_single_handle(handle, client, cached_products)
    end
  end

  def process_single_handle(handle, client, cached_products)
    product = cached_products[handle.downcase] || fetch_live_product(client, handle)
    return unless product.is_a?(Hash)

    product = product.deep_dup
    sanitize_product_stock!(product)
    register_product_item(handle, product)
  end

  def register_product_item(handle, product)
    title = build_card_title(product)
    description = build_card_description(product)
    product_url = extract_product_url(product) || product_url_for_handle(handle)
    image_url = extract_image_url(product)

    @shown_handles << handle
    @shown_product_urls << product_url if product_url.present?

    if image_url.present? && allowed_image_url?(image_url)
      @cards_items << build_card_payload(title, description, image_url, product_url)
    else
      @article_items << build_article_payload(title, description, product_url)
    end
  end

  def build_card_payload(title, description, image_url, product_url)
    actions = []
    actions << { 'type' => 'link', 'text' => 'View product', 'uri' => product_url } if product_url.present? && allowed_link_url?(product_url)

    {
      'title' => title,
      'description' => description,
      'media_url' => image_url,
      'actions' => actions
    }
  end

  def build_article_payload(title, description, product_url)
    payload = { 'title' => title, 'description' => description }
    payload['link'] = product_url if product_url.present? && allowed_link_url?(product_url)
    payload
  end

  def load_cached_products
    state = @run_result&.context&.dig(:state) || {}
    cache = state[Captain::Assistant::PRODUCT_CACHE_STATE_KEY] || state[:cached_products] || {}
    cache.transform_keys { |key| key.to_s.downcase }
  end

  def fetch_live_product(client, handle)
    return fallback_product(handle) unless client

    client.get_product(handle: handle) || fallback_product(handle)
  rescue StandardError => e
    Rails.logger.warn("[Captain] Failed to fetch product #{handle}: #{e.message}") if defined?(Rails) && Rails.respond_to?(:logger)
    fallback_product(handle)
  end

  def fallback_product(handle)
    {
      'handle' => handle,
      'title' => handle.tr('-_', ' ').titleize,
      'product_url' => product_url_for_handle(handle)
    }
  end

  def build_card_title(product)
    title = product['title'].presence || product['handle'].to_s.tr('-_', ' ').titleize
    title = ActionController::Base.helpers.strip_tags(title.to_s) if defined?(ActionController::Base)
    title = strip_stock_phrases(title) if hide_stock?
    title.to_s.strip.truncate(MAX_TITLE_LENGTH, omission: '...')
  end

  def build_card_description(product)
    price = extract_price(product)
    differentiator = extract_differentiator(product)

    combined = if price.present? && differentiator.present?
                 "#{price} — #{differentiator}"
               elsif price.present?
                 price
               else
                 differentiator.presence || ''
               end

    combined = strip_stock_phrases(combined) if hide_stock?
    combined.strip.truncate(MAX_DESCRIPTION_LENGTH, omission: '...')
  end

  def extract_price(product)
    variants = Array(product['variants']).select { |v| v.is_a?(Hash) }
    if variants.present?
      first = variants.first
      price_val = first['price'].to_s.strip
      currency = first['currency'].to_s.strip
      return price_val if price_val.blank?
      return "#{price_val} #{currency}".strip if currency.present? && price_val.exclude?(currency)

      price_val
    elsif product['price'].present?
      product['price'].to_s.strip
    end
  end

  def extract_differentiator(product)
    desc = product['description'].to_s
    desc = ActionController::Base.helpers.strip_tags(desc) if defined?(ActionController::Base)
    desc = desc.gsub(/[*_`#]/, '')
    desc = strip_stock_phrases(desc) if hide_stock?
    desc = desc.gsub(/\b(in\s+stock|out\s+of\s+stock|available|inventory)\b[^\n.]*[\n.]?/i, '')
    desc = desc.gsub(%r{https?://\S+}, '')
    first_sentence = desc.split(/[.\n]/).map(&:strip).reject(&:blank?).first
    first_sentence.presence || desc.strip
  end

  def strip_stock_phrases(text)
    return text if text.blank?

    cleaned = text.to_s.gsub(STOCK_PHRASE_REGEX, '')
    cleaned = cleaned.gsub(/\(\s*\)/, '').gsub(/\[\s*\]/, '')
    cleaned = cleaned.gsub(/\s*[-—–,:]\s*([.!?,])/, '\1')
                     .gsub(/\.\s*\./, '.')
                     .gsub(/^[ \t]*[-—–,:.]+[ \t]*/, '')
                     .gsub(/[ \t]*[-—–,:.]+[ \t]*$/, '')
                     .gsub(/[ \t]{2,}/, ' ')
    cleaned.strip
  end

  def extract_image_url(product)
    product['image_url'].presence ||
      product.dig('image', 'src') ||
      product['images']&.first&.dig('src')
  end

  def extract_product_url(product)
    return product['product_url'] if product['product_url'].present?

    product_url_for_handle(product['handle'])
  end

  def product_url_for_handle(handle)
    return if handle.blank?

    hook = shopify_hook
    return unless hook&.shopify_connected?

    base_url = hook.shopify_storefront_url.presence || "https://#{hook.reference_id}"
    base_url = "https://#{base_url}" unless base_url.to_s.start_with?('http://', 'https://')
    "#{base_url.chomp('/')}/products/#{handle}"
  end

  def sanitizer
    @sanitizer ||= Captain::Conversation::ReplySanitizer.new(assistant: @assistant)
  end

  def allowed_image_url?(url)
    sanitizer.allowed_image_url?(url)
  end

  def allowed_link_url?(url)
    sanitizer.allowed_link_url?(url)
  end

  def sanitize_product_stock!(product)
    return unless product.is_a?(Hash)

    product.delete('available')
    product.delete('stock')
    product.delete('inventory')
    Array(product['variants']).each do |variant|
      next unless variant.is_a?(Hash)

      variant.delete('available')
      variant.delete('stock')
      variant.delete('inventory')
    end
  end

  def shopify_hook
    @assistant.account.hooks.find_by(app_id: 'shopify')
  end

  def shopify_sat_client
    hook = shopify_hook
    return nil unless hook&.shopify_connected? && hook.shopify_tool_key.present?

    hook.shopify_sat_client
  end
end
# rubocop:enable Metrics/ClassLength

# frozen_string_literal: true

module Captain::Tools::ShopifyToolHelpers
  def shopify_hook
    @assistant.account.hooks.find_by(app_id: 'shopify')
  end

  def shopify_sat_client
    hook = shopify_hook
    return nil unless hook&.shopify_connected? && hook.shopify_tool_key.present?

    hook.shopify_sat_client
  end

  def hide_stock?
    shopify_hook&.settings&.dig('hide_stock') == true ||
      @assistant.config&.dig('hide_stock') == true ||
      @assistant.account.custom_attributes&.dig('hide_stock') == true
  end

  def sanitize_product_stock!(product)
    return product unless hide_stock? && product.is_a?(Hash)

    product.delete('available')
    product.delete('stock')
    product.delete('inventory')
    Array(product['variants']).each do |variant|
      next unless variant.is_a?(Hash)

      variant.delete('available')
      variant.delete('stock')
      variant.delete('inventory')
    end
    product
  end

  def record_product_handles(tool_context, handles)
    clean_handles = sanitize_handles(handles)
    return if clean_handles.blank? || tool_context&.state.nil?

    tool_context.state[:product_handles] = (Array(tool_context.state[:product_handles]) | clean_handles)
    tool_context.state[Captain::Assistant::PRODUCT_HANDLES_STATE_KEY] = (
      Array(tool_context.state[Captain::Assistant::PRODUCT_HANDLES_STATE_KEY]) | clean_handles
    )
  end

  def cache_products(tool_context, products)
    return if tool_context&.state.nil?

    cached = tool_context.state[Captain::Assistant::PRODUCT_CACHE_STATE_KEY] ||= {}
    Array(products).select { |p| p.is_a?(Hash) && p['handle'].present? }.each do |p|
      cached[p['handle'].to_s.strip.downcase] = p
    end
    tool_context.state[:cached_products] = cached
  end

  def sanitize_handles(handles)
    Array(handles).compact.map(&:to_s).map(&:strip).reject(&:blank?)
  end
end

# frozen_string_literal: true

class Captain::Tools::TrackOrderTool < Captain::Tools::BasePublicTool
  include Captain::Tools::ShopifyToolHelpers

  description 'Track a customer order only when both the order number and the checkout email are known. ' \
              'Ask once for whatever is missing; then call it immediately.'
  param :order_number, type: 'string', desc: 'Customer-visible Shopify order number (e.g. #1001 or 1001)', required: true
  param :customer_email, type: 'string', desc: 'Customer email address used to verify ownership of the order', required: true

  def perform(tool_context, order_number:, customer_email:)
    client = shopify_sat_client
    unless client && @assistant.shopify_order_tracking_available?
      return failure_result('Shopify is not connected for this account', tool_context.state)
    end

    validation_error = validate_input(order_number, customer_email)
    return validation_error if validation_error

    lookup_and_format_order(client, order_number.to_s.strip, customer_email.to_s.strip)
  rescue ShopifyAgentTools::Client::Error => e
    Rails.logger.warn("SAT track_order failed: #{e.message}") if defined?(Rails) && Rails.respond_to?(:logger)
    failure_result("Failed to track order: #{e.message}", tool_context.state)
  end

  def active?
    @assistant.shopify_order_tracking_available?
  end

  private

  def safe_to_run_after_new_customer_message?
    true
  end

  def validate_input(order_number, customer_email)
    return 'Order number is required to track an order. Please ask the customer for their order number.' if order_number.to_s.strip.blank?

    if customer_email.to_s.strip.blank?
      return 'Customer email is required to verify ownership of the order. Please ask the customer for their email address.'
    end

    clean_email = customer_email.to_s.strip
    unless clean_email.match?(URI::MailTo::EMAIL_REGEXP)
      return "The email address '#{clean_email}' is invalid. Please confirm the email address associated with the order."
    end

    nil
  end

  def lookup_and_format_order(client, clean_order_number, clean_email)
    log_tool_usage('tracking_order', { order_number: clean_order_number })
    result = client.track_order(order_number: clean_order_number, customer_email: clean_email)
    unless result && result['found']
      log_tool_usage('order_not_found', { order_number: clean_order_number })
      return "No order was found matching order number '#{clean_order_number}' and email '#{clean_email}'. " \
             'Please verify the details with the customer.'
    end

    log_tool_usage('order_found', { order_number: clean_order_number, status: result['fulfillment_status'] })
    format_order(result)
  end

  def format_order(order)
    lines = ["Order: #{order['order_number']}"]
    lines << "Status: #{order['fulfillment_status'].presence || 'Unfulfilled'}"
    lines << "Financial status: #{order['financial_status']}" if order['financial_status'].present?
    lines << "Placed on: #{order['created_at']}" if order['created_at'].present?

    append_fulfillments!(lines, order['fulfillments'])
    append_order_items!(lines, order['items'])

    lines << "Order status page: #{order['status_page_url']}" if order['status_page_url'].present?
    lines.join("\n")
  end

  def append_fulfillments!(lines, fulfillments)
    return if fulfillments.blank?

    lines << "\nShipment tracking:"
    fulfillments.each { |f| lines << format_fulfillment(f) }
  end

  def format_fulfillment(fulfillment)
    status_label = fulfillment['display_status'] || fulfillment['status'] || 'In transit'
    shipment = "  - Shipment status: #{status_label}"
    shipment += " (Estimated delivery: #{fulfillment['estimated_delivery_at']})" if fulfillment['estimated_delivery_at'].present?

    tracking = format_tracking_info(fulfillment['tracking'])
    shipment += "\n    Tracking: #{tracking}" if tracking.present?

    items = Array(fulfillment['items']).map { |item| "#{item['name']} (x#{item['quantity']})" }
    shipment += "\n    Shipped items: #{items.join(', ')}" if items.present?
    shipment
  end

  def format_tracking_info(tracking_list)
    Array(tracking_list).filter_map do |t|
      info = [t['company'], t['number']].compact.join(' ')
      info += " (#{t['url']})" if t['url'].present?
      info.presence
    end.join(', ')
  end

  def append_order_items!(lines, items)
    return if items.blank?

    lines << "\nOrdered items:"
    items.each do |item|
      lines << "  - #{item['name']} (x#{item['quantity']})"
    end
  end
end

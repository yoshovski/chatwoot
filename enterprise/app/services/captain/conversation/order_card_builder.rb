# The order the order tool found in this run, as one card under the answer: order name and date, a plain status line,
# the first items, and a button to the tracking page (or the store's order page). The links come from Shopify through
# the order tool, so they skip the reply link allowlist like the rest of the tool data.
class Captain::Conversation::OrderCardBuilder
  MAX_ITEMS = 3
  MAX_DESCRIPTION_LENGTH = 200

  def initialize(assistant:, run_result:)
    @assistant = assistant
    @order = assistant.run_result_order(run_result)
  end

  def build_messages
    return [] if @order.blank?

    I18n.with_locale(@assistant.account.locale) do
      item = { 'title' => title, 'description' => description, 'actions' => actions }
      [{ content: item['title'], content_type: 'cards', content_attributes: { items: [item] } }]
    end
  end

  private

  def title
    date = @order['created_at'].present? ? I18n.l(Time.zone.parse(@order['created_at']).to_date, format: '%b %-d, %Y') : nil
    order = @order['order_number'].to_s.delete_prefix('#')
    date ? I18n.t('captain.order_card.title', order: order, date: date) : order
  end

  def description
    [status_line, *item_lines].compact.join("\n").truncate(MAX_DESCRIPTION_LENGTH)
  end

  def status_line
    return Captain::OrderStatus.cancelled if @order['cancelled_at'].present?

    parts = [Captain::OrderStatus.payment(@order['financial_status'])]
    shipment = latest_fulfillment
    if shipment
      parts << (Captain::OrderStatus.shipment(shipment['display_status']) || Captain::OrderStatus.fulfillment(@order['fulfillment_status']))
      parts << arrival(shipment['estimated_delivery_at'])
    else
      parts << Captain::OrderStatus.fulfillment(@order['fulfillment_status'])
    end
    parts.compact.join(' · ')
  end

  def arrival(estimated_delivery_at)
    return if estimated_delivery_at.blank?

    I18n.t('captain.order_card.arrives', date: I18n.l(Time.zone.parse(estimated_delivery_at).to_date, format: '%b %-d'))
  end

  def item_lines
    items = Array(@order['items'])
    lines = items.first(MAX_ITEMS).map { |item| I18n.t('captain.order_card.item', quantity: item['quantity'], name: item['name']) }
    lines << I18n.t('captain.order_card.more_items', count: items.size - MAX_ITEMS) if items.size > MAX_ITEMS
    lines
  end

  def actions
    tracking_url = Array(latest_fulfillment&.dig('tracking')).filter_map { |tracking| tracking['url'].presence }.first
    return [link('track_package', tracking_url)] if tracking_url

    @order['status_page_url'].present? ? [link('view_order', @order['status_page_url'])] : []
  end

  def link(label_key, uri)
    { 'type' => 'link', 'text' => I18n.t("captain.order_card.#{label_key}"), 'uri' => uri }
  end

  def latest_fulfillment
    Array(@order['fulfillments']).last
  end
end

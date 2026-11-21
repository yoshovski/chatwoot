# The order the order tool found in this run, as one card under the answer: order name and date, a plain status line,
# the first items, and a button to the tracking page (or the store's order page). The links come from Shopify through
# the order tool, so they skip the reply link allowlist like the rest of the tool data.
class Captain::Conversation::OrderCardBuilder
  MAX_ITEMS = 3
  MAX_DESCRIPTION_LENGTH = 200

  def initialize(assistant:, run_result:)
    @locale = run_result&.context&.dig(:state, Captain::Conversation::CustomerLocale::STATE_KEY) || assistant.account.locale
    @order = assistant.run_result_order(run_result)
  end

  def build_messages
    return [] if @order.blank?

    I18n.with_locale(@locale) do
      item = { 'title' => title, 'description' => description, 'actions' => actions }
      [{ content: item['title'], content_type: 'cards', content_attributes: { items: [item] } }]
    end
  end

  private

  def title
    date = format_date(@order['created_at'], 'date_format', '%Y-%m-%d') if @order['created_at'].present?
    order = @order['order_number'].to_s.delete_prefix('#')
    date ? card_copy('title', order: order, date: date) : order
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

    card_copy('arrives', date: format_date(estimated_delivery_at, 'arrival_date_format', '%m-%d'))
  end

  def format_date(timestamp, key, fallback)
    format = I18n.t("captain.order_card.#{key}", default: nil, fallback: false) || fallback
    I18n.l(Time.zone.parse(timestamp).to_date, format: format)
  end

  def card_copy(key, **)
    path = "captain.order_card.#{key}"
    I18n.t(path, default: nil, **) || I18n.t(path, locale: :en, **)
  end

  def item_lines
    items = Array(@order['items'])
    lines = items.first(MAX_ITEMS).map { |item| card_copy('item', quantity: item['quantity'], name: item['name']) }
    lines << card_copy('more_items', count: items.size - MAX_ITEMS) if items.size > MAX_ITEMS
    lines
  end

  def actions
    tracking_url = Array(latest_fulfillment&.dig('tracking')).filter_map { |tracking| tracking['url'].presence }.first
    return [link('track_package', tracking_url)] if tracking_url

    @order['status_page_url'].present? ? [link('view_order', @order['status_page_url'])] : []
  end

  def link(label_key, uri)
    { 'type' => 'link', 'text' => card_copy(label_key), 'uri' => uri }
  end

  def latest_fulfillment
    Array(@order['fulfillments']).last
  end
end

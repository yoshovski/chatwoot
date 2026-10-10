# Plain-language labels for Shopify's order status values (PAID, UNFULFILLED, IN_TRANSIT, ...), shared by the
# order tool's text for the model and the order card the customer sees.
module Captain::OrderStatus
  module_function

  def payment(status) = label('payment', status)

  # Shopify leaves the fulfillment status empty until something ships.
  def fulfillment(status) = label('fulfillment', status.presence || 'UNFULFILLED')

  def shipment(status) = label('shipment', status)

  def cancelled = I18n.t('captain.order_status.cancelled')

  def label(group, status)
    return if status.blank?

    key = status.to_s.downcase
    I18n.t("captain.order_status.#{group}.#{key}", default: key.humanize)
  end
end

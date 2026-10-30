# Applies Telnyx delivery receipts (message.sent / message.finalized) to outgoing messages.
# https://developers.telnyx.com/docs/messaging/messages/message-detail-records
class Telnyx::DeliveryStatusService
  STATUS_MAP = {
    'sent' => 'sent',
    'delivered' => 'delivered',
    'sending_failed' => 'failed',
    'delivery_failed' => 'failed'
  }.freeze

  pattr_initialize [:inbox!, :payload!]

  def perform
    return if message.blank? || status.blank?
    # Telnyx can deliver message.sent after message.finalized; never step a delivered message back.
    return if status == 'sent' && message.delivered?

    message.status = status
    message.external_error = external_error if status == 'failed'
    message.save!
  end

  private

  def message
    return if payload[:id].blank?

    @message ||= inbox.messages.find_by(source_id: payload[:id])
  end

  def status
    STATUS_MAP[Array(payload[:to]).first&.dig(:status)]
  end

  def external_error
    error = Array(payload[:errors]).first
    return 'Delivery failed' if error.blank?

    [error[:code], error[:title] || error[:detail]].compact.join(' - ')
  end
end

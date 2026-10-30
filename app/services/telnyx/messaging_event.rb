# Reads a Telnyx messaging webhook and resolves the Telnyx SMS channel it belongs to.
# Inbound messages are addressed to our number; delivery events come from it.
class Telnyx::MessagingEvent
  INBOUND_EVENTS = %w[message.received].freeze
  STATUS_EVENTS = %w[message.sent message.finalized].freeze

  def initialize(params)
    @data = (params || {}).with_indifferent_access[:data] || {}
  end

  def event_type
    @data[:event_type].to_s
  end

  def payload
    @data[:payload] || {}
  end

  def inbound?
    INBOUND_EVENTS.include?(event_type)
  end

  def status_event?
    STATUS_EVENTS.include?(event_type)
  end

  def channel
    return if our_number.blank?

    @channel ||= Channel::Sms.find_by(phone_number: our_number, provider: 'telnyx')
  end

  private

  def our_number
    if inbound?
      Array(payload[:to]).first&.dig(:phone_number)
    elsif status_event?
      payload.dig(:from, :phone_number)
    end
  end
end

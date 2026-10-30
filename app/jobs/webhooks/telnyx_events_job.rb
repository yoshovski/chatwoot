class Webhooks::TelnyxEventsJob < ApplicationJob
  queue_as :default

  def perform(params = {})
    event = Telnyx::MessagingEvent.new(params)
    channel = event.channel
    return if channel&.inbox.blank?

    if event.inbound?
      Telnyx::IncomingMessageService.new(inbox: channel.inbox, payload: event.payload).perform
    elsif event.status_event?
      Telnyx::DeliveryStatusService.new(inbox: channel.inbox, payload: event.payload).perform
    end
  end
end

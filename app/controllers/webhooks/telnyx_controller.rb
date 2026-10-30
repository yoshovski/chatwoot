# Messaging webhooks for Telnyx SMS inboxes. Telnyx posts one event per request:
# { data: { event_type:, payload: { from:, to: [...], text:, media: [...] } } }
class Webhooks::TelnyxController < ActionController::API
  def process_payload
    channel = Telnyx::MessagingEvent.new(event_params).channel
    return head :ok if channel.blank?
    return head :unauthorized unless Telnyx::WebhookSignature.verify_request!(channel, request)

    Webhooks::TelnyxEventsJob.perform_later(event_params)
    head :ok
  end

  private

  def event_params
    @event_params ||= params.to_unsafe_hash.slice('data')
  end
end

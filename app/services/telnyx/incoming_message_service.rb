# Maps a Telnyx `message.received` payload onto the shared SMS inbound flow.
# https://developers.telnyx.com/docs/messaging/messages/receiving-webhooks
class Telnyx::IncomingMessageService
  pattr_initialize [:inbox!, :payload!]

  def perform
    return if payload[:id].blank? || duplicate?

    Sms::IncomingMessageService.new(inbox: inbox, params: sms_params).perform
  end

  private

  # Telnyx retries webhooks that don't get a fast 200, so the same message can arrive twice.
  def duplicate?
    inbox.messages.exists?(source_id: payload[:id])
  end

  def sms_params
    {
      id: payload[:id],
      from: payload.dig(:from, :phone_number),
      text: payload[:text],
      media: Array(payload[:media]).filter_map { |media| media[:url] }
    }.with_indifferent_access
  end
end

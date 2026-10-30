# Sends SMS/MMS through Telnyx's Messaging API.
# https://developers.telnyx.com/api-reference/messages/send-a-message
class Sms::Providers::TelnyxService
  pattr_initialize [:channel!]

  def api_base_path
    ::Telnyx::ApiClient::BASE_URL
  end

  def send_message(contact_number, message)
    body = message_body(contact_number, message.outgoing_content)
    body[:media_urls] = message.attachments.map(&:download_url) if message.attachments.present?

    deliver(body, message)
  end

  def send_text_message(contact_number, message_content)
    deliver(message_body(contact_number, message_content))
  end

  private

  def message_body(contact_number, message_content)
    {
      from: channel.phone_number,
      to: contact_number,
      text: message_content.presence,
      messaging_profile_id: channel.provider_config['messaging_profile_id'].presence,
      # Per-message webhook so delivery receipts reach us even if the profile's URL points elsewhere.
      webhook_url: channel.messaging_webhook_url
    }.compact
  end

  def deliver(body, message = nil)
    response = client.post('/messages', body)
    response.dig('data', 'id')
  rescue ::Telnyx::ApiClient::Error => e
    Rails.logger.error("[#{channel.account_id}] Error sending Telnyx SMS: #{e.message}")
    mark_failed(message, e.message)
    nil
  end

  def mark_failed(message, error)
    return if message.blank?

    message.external_error = error
    message.status = :failed
    message.save!
  end

  def client
    @client ||= ::Telnyx::ApiClient.new(channel.provider_config['api_key'])
  end
end

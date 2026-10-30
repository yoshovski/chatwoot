class Sms::Providers::BandwidthService
  API_BASE_PATH = 'https://messaging.bandwidth.com/api/v2'.freeze

  pattr_initialize [:channel!]

  def api_base_path
    API_BASE_PATH
  end

  def send_message(contact_number, message)
    body = message_body(contact_number, message.outgoing_content)
    body['media'] = message.attachments.map(&:download_url) if message.attachments.present?

    send_to_bandwidth(body, message)
  end

  def send_text_message(contact_number, message_content)
    send_to_bandwidth(message_body(contact_number, message_content))
  end

  private

  def provider_config
    channel.provider_config
  end

  def message_body(contact_number, message_content)
    {
      'to' => contact_number,
      'from' => channel.phone_number,
      'text' => message_content,
      'applicationId' => provider_config['application_id']
    }
  end

  def send_to_bandwidth(body, message = nil)
    response = HTTParty.post(
      "#{api_base_path}/users/#{provider_config['account_id']}/messages",
      basic_auth: bandwidth_auth,
      headers: { 'Content-Type' => 'application/json' },
      body: body.to_json
    )

    if response.success?
      response.parsed_response['id']
    else
      handle_error(response, message)
      nil
    end
  end

  def handle_error(response, message)
    Rails.logger.error("[#{channel.account_id}] Error sending SMS: #{response.parsed_response['description']}")
    return if message.blank?

    # https://dev.bandwidth.com/apis/messaging-apis/messaging/#tag/Messages/operation/createMessage
    message.external_error = response.parsed_response['description']
    message.status = :failed
    message.save!
  end

  def bandwidth_auth
    { username: provider_config['api_key'], password: provider_config['api_secret'] }
  end
end

# Points the inbox's Telnyx messaging profile at our webhook and makes sure the number sends
# and receives through that profile, so a new inbox works without manual portal setup.
class Telnyx::WebhookSetupService
  pattr_initialize [:channel!]

  def perform
    profile_id = channel.provider_config['messaging_profile_id']
    return Rails.logger.warn("TELNYX_MESSAGING_PROFILE_MISSING: #{channel.phone_number}") if profile_id.blank?

    client.patch("/messaging_profiles/#{profile_id}", webhook_url: channel.messaging_webhook_url, webhook_api_version: '2')
    assign_number_to_profile(profile_id)
  end

  private

  def assign_number_to_profile(profile_id)
    number_id = Telnyx::PhoneNumberLookup.new(client: client).id_for(channel.phone_number)
    return Rails.logger.warn("TELNYX_PHONE_NUMBER_NOT_FOUND: #{channel.phone_number}") if number_id.blank?

    client.patch("/phone_numbers/#{number_id}/messaging", messaging_profile_id: profile_id)
  end

  def client
    @client ||= Telnyx::ApiClient.new(channel.provider_config['api_key'])
  end
end

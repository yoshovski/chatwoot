# A Telnyx voice inbox is a Telnyx SMS channel with voice turned on; the model provisions
# the TeXML application and agent credential connection, and sets up the messaging webhook.
class Telnyx::VoiceChannelBuilder
  CONFIG_KEYS = %i[api_key account_sid messaging_profile_id outbound_voice_profile_id public_key].freeze

  pattr_initialize [:account!, :params!]

  def perform
    voice_params = params.require(:channel).permit(:phone_number, provider_config: CONFIG_KEYS)

    account.sms_channels.create!(
      phone_number: voice_params[:phone_number],
      provider: 'telnyx',
      provider_config: (voice_params[:provider_config] || {}).to_h.merge('voice_enabled' => true)
    )
  end
end

# Voice calling for Telnyx SMS inboxes. All voice settings live in provider_config:
# voice_enabled, account_sid, outbound_voice_profile_id, plus the provisioned
# texml_application_id / credential_connection_id and per-agent WebRTC credentials.
module Enterprise::Channel::Sms
  include Concerns::CallRecordingSettings

  def self.prepended(base)
    base.class_eval do
      before_validation :provision_telnyx_voice, if: :voice_needs_provisioning?
    end
  end

  # Written by us, never by the settings form; keep them when an update replaces provider_config.
  MANAGED_CONFIG_KEYS = %w[texml_application_id credential_connection_id agent_credentials].freeze

  def provider_config=(value)
    preserved = (self[:provider_config] || {}).slice(*MANAGED_CONFIG_KEYS)
    super(preserved.merge((value || {}).to_h.stringify_keys))
  end

  def voice_enabled?
    telnyx? && ActiveModel::Type::Boolean.new.cast(provider_config['voice_enabled']) == true
  end

  def voice_configured?
    voice_enabled? && provider_config['texml_application_id'].present?
  end

  # Mutes only the incoming side of calling; default on, so only an explicit false disables inbound.
  def inbound_calls_enabled?
    provider_config['inbound_calls_enabled'] != false
  end

  # nil for Bandwidth inboxes and Telnyx inboxes without voice, so voice endpoints reject them.
  def voice_provider
    :telnyx if voice_enabled?
  end

  def initiate_call(to:, conference_sid: nil, agent_id: nil)
    Voice::Provider::Telnyx::Adapter.new(self).initiate_call(to: to, conference_sid: conference_sid, agent_id: agent_id)
  end

  def voice_call_webhook_url(**query)
    Rails.application.routes.url_helpers.telnyx_voice_call_url(phone: phone_digits, **query)
  end

  def voice_status_webhook_url(**query)
    Rails.application.routes.url_helpers.telnyx_voice_status_url(phone: phone_digits, **query)
  end

  def voice_conference_status_webhook_url(**query)
    Rails.application.routes.url_helpers.telnyx_voice_conference_status_url(phone: phone_digits, **query)
  end

  def voice_recording_status_webhook_url(**query)
    Rails.application.routes.url_helpers.telnyx_voice_recording_status_url(phone: phone_digits, **query)
  end

  private

  def phone_digits
    phone_number.delete_prefix('+')
  end

  def voice_needs_provisioning?
    voice_enabled? && phone_number.present? &&
      (provider_config['texml_application_id'].blank? || provider_config['credential_connection_id'].blank?)
  end

  def provision_telnyx_voice
    if provider_config['account_sid'].blank?
      errors.add(:base, 'Telnyx voice setup failed: account ID is required')
      return
    end

    self.provider_config = provider_config.merge(Telnyx::VoiceSetupService.new(channel: self).perform)
  rescue StandardError => e
    Rails.logger.error("TELNYX_VOICE_SETUP_ERROR: #{e.class} #{e.message} phone=#{phone_number} account=#{account_id}")
    errors.add(:base, "Telnyx voice setup failed: #{e.message}")
  end
end

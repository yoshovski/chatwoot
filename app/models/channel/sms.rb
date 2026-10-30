# == Schema Information
#
# Table name: channel_sms
#
#  id              :bigint           not null, primary key
#  phone_number    :string           not null
#  provider        :string           default("default")
#  provider_config :jsonb
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :integer          not null
#
# Indexes
#
#  index_channel_sms_on_phone_number  (phone_number) UNIQUE
#

class Channel::Sms < ApplicationRecord
  include Channelable

  self.table_name = 'channel_sms'
  # 'default' is Bandwidth, the original provider of this channel.
  PROVIDERS = %w[default telnyx].freeze
  EDITABLE_ATTRS = [:phone_number, :provider, { provider_config: {} }].freeze

  validates :phone_number, presence: true, uniqueness: true
  validates :provider, inclusion: { in: PROVIDERS }

  after_create_commit :setup_telnyx_messaging_webhook, if: :telnyx?

  delegate :api_base_path, :send_message, :send_text_message, to: :provider_service

  def name
    telnyx? ? 'Telnyx SMS' : 'Sms'
  end

  def telnyx?
    provider == 'telnyx'
  end

  def provider_service
    @provider_service ||= if telnyx?
                            Sms::Providers::TelnyxService.new(channel: self)
                          else
                            Sms::Providers::BandwidthService.new(channel: self)
                          end
  end

  def messaging_webhook_url
    Rails.application.routes.url_helpers.telnyx_messaging_webhook_url if telnyx?
  end

  private

  def setup_telnyx_messaging_webhook
    Channels::Telnyx::WebhookSetupJob.perform_later(self)
  end
end

Channel::Sms.prepend_mod_with('Channel::Sms')

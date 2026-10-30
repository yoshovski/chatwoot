class Channels::Telnyx::WebhookSetupJob < ApplicationJob
  queue_as :low

  def perform(channel)
    ::Telnyx::WebhookSetupService.new(channel: channel).perform
  end
end

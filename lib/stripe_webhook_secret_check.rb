# Billing is on when STRIPE_SECRET_KEY is set. Without STRIPE_WEBHOOK_SECRET no webhook can be verified, so every
# Stripe event would be refused; production refuses to boot instead of failing silently.
module StripeWebhookSecretCheck
  class MissingSecretError < StandardError; end

  def self.verify!(env: ENV, rails_env: Rails.env)
    return unless rails_env.production?
    return if env['STRIPE_SECRET_KEY'].blank? || env['STRIPE_WEBHOOK_SECRET'].present?

    raise MissingSecretError, 'STRIPE_SECRET_KEY is set but STRIPE_WEBHOOK_SECRET is blank. Set the webhook signing secret from ' \
                              'the Stripe dashboard, or unset STRIPE_SECRET_KEY to turn billing off.'
  end
end

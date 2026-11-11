require 'stripe'

Stripe.api_key = ENV.fetch('STRIPE_SECRET_KEY', nil)

Rails.application.config.after_initialize { StripeWebhookSecretCheck.verify! }

# Stripe's hosted confirmation reviews prorations and handles payment authentication.
# Preparing this flow must never change or resume a subscription on its own.
class Enterprise::Billing::AccountIntervalChangeService
  Unavailable = Enterprise::Billing::AccountCheckoutService::Unavailable

  def initialize(account:)
    @account = account
  end

  def perform(interval:)
    @account.with_lock do
      remote = Enterprise::Billing::AccountSubscriptionSyncService.refresh(@account)
      subscription = @account.subscription_settings
      subscription.reload if subscription.persisted?
      raise Unavailable unless subscription.interval_change_available? && @account.billing_provider == 'stripe'

      validate_target(subscription, remote, interval)

      { url: confirmation_session(subscription, remote, interval).url }
    end
  end

  private

  def validate_target(subscription, remote, interval)
    raise Unavailable if subscription.billing_interval == interval || remote.cancel_at_period_end || remote['cancel_at'].present?
    raise Unavailable unless remote.customer == subscription.stripe_customer_id && remote.metadata['chatoctave_account_id'] == @account.id.to_s
  end

  def confirmation_session(subscription, remote, interval)
    item = remote.items.data.first
    prices = %w[month year].index_with { |frequency| price(subscription, item.price, frequency) }
    configuration = portal_configuration(item.price.product, prices.values.map(&:id))
    return_url = "#{ENV.fetch('FRONTEND_URL').chomp('/')}/app/accounts/#{@account.id}/settings/billing"
    Stripe::BillingPortal::Session.create(
      customer: subscription.stripe_customer_id, configuration: configuration.id, return_url: return_url,
      flow_data: { type: 'subscription_update_confirm',
                   subscription_update_confirm: { subscription: remote.id,
                                                  items: [{ id: item.id, price: prices.fetch(interval).id, quantity: item.quantity }] },
                   after_completion: { type: 'redirect', redirect: { return_url: return_url } } }
    )
  end

  def price(subscription, current_price, interval)
    amount = interval == 'year' ? subscription.annual_amount_cents : subscription.monthly_price_cents
    params = { product: current_price.product, currency: subscription.currency, unit_amount: amount,
               recurring: { interval: interval }, tax_behavior: current_price.tax_behavior }
    key = Digest::SHA256.hexdigest(params.to_json)
    Stripe::Price.create(params, { idempotency_key: "account-interval-price-#{subscription.id}-#{key}" })
  end

  def portal_configuration(product, prices)
    features = {
      subscription_update: { enabled: true, default_allowed_updates: ['price'],
                             products: [{ product: product, prices: prices }], proration_behavior: 'always_invoice' },
      payment_method_update: { enabled: true }, invoice_history: { enabled: true },
      subscription_cancel: { enabled: true, mode: 'at_period_end' }
    }
    Stripe::BillingPortal::Configuration.create(
      { features: features }, { idempotency_key: "account-interval-portal-#{Digest::SHA256.hexdigest(features.to_json)}" }
    )
  end
end

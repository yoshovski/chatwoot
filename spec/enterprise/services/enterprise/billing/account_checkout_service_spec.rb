require 'rails_helper'

describe Enterprise::Billing::AccountCheckoutService do
  subject(:service) { described_class.new(account: account) }

  let(:account) { create(:account) }
  let(:plan) do
    create(:billing_plan, name: 'Starter', monthly_price_cents: 2900).tap do |record|
      record.update!(stripe_product_id: 'prod_starter', stripe_monthly_price_id: 'price_starter_month', stripe_annual_price_id: 'price_starter_year')
    end
  end
  let(:session) { Stripe::Checkout::Session.construct_from(id: 'cs_test', url: 'https://checkout.stripe.test/cs_test') }

  before do
    account.update!(subscription_settings: { billing_plan_id: plan.id })
    allow(Stripe::Customer).to receive(:create).and_return(Stripe::Customer.construct_from(id: 'cus_test'))
    allow(Stripe::Checkout::Session).to receive(:create).and_return(session)
  end

  around { |example| with_modified_env(FRONTEND_URL: 'https://app.example.com') { example.run } }

  it 'sells the plan price with address, VAT ID, automatic tax and promotion codes' do
    expect(service.checkout(interval: 'year', plan: plan)).to eq(url: session.url)

    expect(Stripe::Checkout::Session).to have_received(:create).with(
      hash_including(customer: 'cus_test', mode: 'subscription', line_items: [{ price: 'price_starter_year', quantity: 1 }],
                     automatic_tax: { enabled: true }, tax_id_collection: { enabled: true }, billing_address_collection: 'required',
                     customer_update: { address: 'auto', name: 'auto' }, allow_promotion_codes: true),
      hash_including(:idempotency_key)
    )
    expect(account.account_subscription.reload.stripe_checkout_session_id).to eq('cs_test')
  end

  it 'refuses a plan that has no Stripe prices yet' do
    plan.update!(monthly_price: '39')

    expect { service.checkout(interval: 'month', plan: plan.reload) }.to raise_error do |error|
      expect(error.class.name).to eq('Enterprise::Billing::AccountCheckoutService::Unavailable')
    end
  end

  it 'sells the price saved on the account when no plan is given' do
    account.update!(subscription_settings: { monthly_price: '50' })

    service.checkout(interval: 'month')

    expect(Stripe::Checkout::Session).to have_received(:create).with(
      hash_including(line_items: [{ price_data: hash_including(unit_amount: 5000, tax_behavior: 'exclusive'), quantity: 1 }],
                     automatic_tax: { enabled: true }),
      anything
    )
  end
end

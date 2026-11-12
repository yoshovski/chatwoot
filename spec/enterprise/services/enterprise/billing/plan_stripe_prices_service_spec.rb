require 'rails_helper'

describe Enterprise::Billing::PlanStripePricesService do
  let(:plan) { create(:billing_plan, name: 'Starter', currency: 'eur', monthly_price_cents: 2900) }

  before do
    allow(Stripe::Product).to receive(:create).and_return(Stripe::Product.construct_from(id: 'prod_starter'))
    allow(Stripe::Price).to receive(:create) do |params, _options|
      Stripe::Price.construct_from(id: "price_starter_#{params[:recurring][:interval]}")
    end
  end

  it 'creates a product and a monthly and yearly price without VAT, yearly at ten months' do
    described_class.new(plan: plan).perform

    expect(plan.reload).to have_attributes(stripe_product_id: 'prod_starter', stripe_monthly_price_id: 'price_starter_month',
                                           stripe_annual_price_id: 'price_starter_year')
    expect(plan).to be_purchasable
    expect(Stripe::Price).to have_received(:create).with(
      hash_including(product: 'prod_starter', currency: 'eur', unit_amount: 2900, recurring: { interval: 'month' }, tax_behavior: 'exclusive'),
      hash_including(:idempotency_key)
    )
    expect(Stripe::Price).to have_received(:create).with(hash_including(unit_amount: 29_000, recurring: { interval: 'year' }), anything)
  end

  it 'keeps the product and creates new prices after the plan price changes' do
    described_class.new(plan: plan).perform
    plan.update!(monthly_price: '39')
    expect(plan.reload).to have_attributes(stripe_monthly_price_id: nil, stripe_annual_price_id: nil, stripe_product_id: 'prod_starter')

    described_class.new(plan: plan).perform

    expect(Stripe::Product).to have_received(:create).once
    expect(Stripe::Price).to have_received(:create).with(hash_including(product: 'prod_starter', unit_amount: 3900), anything)
  end
end

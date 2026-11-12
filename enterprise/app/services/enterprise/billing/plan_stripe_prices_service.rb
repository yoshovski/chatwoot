# Super Admin "Create in Stripe": one Stripe product per plan and one price per interval (annual = two months free).
# Prices exclude VAT; Checkout adds it with automatic tax (or reverse charge for an EU business with a VAT ID).
class Enterprise::Billing::PlanStripePricesService
  def initialize(plan:)
    @plan = plan
  end

  def perform
    @plan.with_lock do
      product_id = @plan.stripe_product_id || create_product.id
      @plan.update!(stripe_product_id: product_id, stripe_monthly_price_id: create_price(product_id, 'month', @plan.monthly_price_cents).id,
                    stripe_annual_price_id: create_price(product_id, 'year', @plan.annual_price_cents).id)
    end
  end

  private

  def create_product
    Stripe::Product.create({ name: @plan.name, metadata: { chatoctave_plan_id: @plan.id.to_s } },
                           { idempotency_key: "chatoctave-plan-product-#{@plan.id}" })
  end

  def create_price(product_id, interval, amount)
    Stripe::Price.create(
      { product: product_id, currency: @plan.currency, unit_amount: amount, recurring: { interval: interval }, tax_behavior: 'exclusive',
        metadata: { chatoctave_plan_id: @plan.id.to_s } },
      { idempotency_key: "chatoctave-plan-price-#{@plan.id}-#{product_id}-#{interval}-#{@plan.currency}-#{amount}" }
    )
  end
end

class AddStripePricesToBillingPlans < ActiveRecord::Migration[7.2]
  def change
    change_table :billing_plans, bulk: true do |t|
      t.string :stripe_product_id
      t.string :stripe_monthly_price_id
      t.string :stripe_annual_price_id
    end
    add_index :billing_plans, :stripe_monthly_price_id, unique: true
    add_index :billing_plans, :stripe_annual_price_id, unique: true
  end
end

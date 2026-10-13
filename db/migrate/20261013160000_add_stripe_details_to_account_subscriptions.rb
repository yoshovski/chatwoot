class AddStripeDetailsToAccountSubscriptions < ActiveRecord::Migration[7.2]
  def change
    add_column :account_subscriptions, :stripe_subscription_details, :jsonb, default: {}, null: false
    add_column :account_subscriptions, :stripe_checkout_session_id, :string
  end
end

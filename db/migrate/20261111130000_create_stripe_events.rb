# Every Stripe webhook event is stored once (unique by Stripe's event id) and handled by a job, so a duplicate
# delivery is a no-op and a failure stays visible. The billing facts on account_subscriptions are what the
# billing emails (T08) and the Super Admin billing page (T10) read.
class CreateStripeEvents < ActiveRecord::Migration[7.2]
  def change
    create_stripe_events
    add_billing_facts
  end

  private

  def create_stripe_events
    create_table :stripe_events do |t|
      t.string :stripe_id, null: false
      t.string :event_type, null: false
      t.string :status, null: false, default: 'received'
      t.text :error
      t.integer :attempts, null: false, default: 0
      t.datetime :processed_at
      t.datetime :stripe_created_at
      t.string :stripe_customer_id
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end
    add_index :stripe_events, :stripe_id, unique: true
    add_index :stripe_events, [:stripe_customer_id, :created_at]
    add_index :stripe_events, [:status, :created_at]
  end

  def add_billing_facts
    change_table :account_subscriptions, bulk: true do |t|
      t.datetime :payment_failed_at
      t.datetime :payment_action_required_at
      t.datetime :trial_will_end_notified_at
      t.datetime :upcoming_invoice_at
      t.datetime :ai_paused_at
      t.string :ai_paused_reason
    end
  end
end

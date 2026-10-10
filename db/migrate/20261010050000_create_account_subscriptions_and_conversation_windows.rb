class CreateAccountSubscriptionsAndConversationWindows < ActiveRecord::Migration[7.1]
  def change # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    create_table :account_subscriptions do |t|
      t.references :account, null: false, index: { unique: true }, foreign_key: true
      t.boolean :enabled, null: false, default: false
      t.integer :monthly_limit
      t.string :billing_interval, null: false, default: 'month'
      t.string :currency, null: false, default: 'eur'
      t.integer :monthly_price_cents, null: false, default: 0
      t.integer :annual_discount_percent, null: false, default: 0
      t.integer :annual_price_cents
      t.integer :setup_fee_cents, null: false, default: 0
      t.boolean :trial_enabled, null: false, default: false
      t.integer :trial_days, null: false, default: 14
      t.datetime :trial_ends_at
      t.datetime :period_started_at
      t.datetime :period_ends_at
      t.datetime :quota_anchor, null: false
      t.string :payment_status, null: false, default: 'manual'
      t.string :stripe_customer_id
      t.datetime :stripe_subscription_created_at
      t.integer :custom_payment_cents, null: false, default: 0
      t.string :custom_payment_description
      t.string :custom_payment_revision
      t.datetime :custom_payment_paid_at
      t.string :stripe_subscription_id
      t.timestamps
    end
    add_index :account_subscriptions, :stripe_customer_id, unique: true
    create_table :conversation_usage_windows do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation, foreign_key: { on_delete: :nullify }
      t.references :message, index: { unique: true }, foreign_key: { on_delete: :nullify }
      t.datetime :started_at, null: false
      t.datetime :ends_at, null: false
      t.datetime :quota_period_start, null: false
      t.timestamps
    end
    add_index :conversation_usage_windows, [:account_id, :quota_period_start], name: 'idx_usage_account_period'
    add_index :conversation_usage_windows, [:conversation_id, :started_at], name: 'idx_usage_conversation_start'
    create_table :account_data_exports do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: 'pending'
      t.string :export_type, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
  end
end

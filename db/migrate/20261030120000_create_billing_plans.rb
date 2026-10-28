class CreateBillingPlans < ActiveRecord::Migration[7.1]
  def change
    create_table :billing_plans do |t|
      t.string :name, null: false, index: { unique: true }
      t.text :description
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.string :currency, null: false, default: 'eur'
      t.integer :monthly_price_cents, null: false, default: 0
      t.integer :ai_conversations_limit
      t.integer :trial_ai_conversations_limit, default: 50
      t.integer :trial_days, null: false, default: 14
      t.integer :agents_limit, :inboxes_limit, :documents_limit
      t.jsonb :features, null: false, default: []
      t.jsonb :add_ons, null: false, default: {}
      t.timestamps
    end

    add_reference :account_subscriptions, :billing_plan, foreign_key: { on_delete: :nullify }
    add_column :account_subscriptions, :add_ons, :jsonb, null: false, default: []
  end
end

class CreateBillingNotifications < ActiveRecord::Migration[7.2]
  def change
    create_table :billing_notifications do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :kind, null: false
      t.string :key, null: false
      t.integer :recipients_count, null: false, default: 0
      t.timestamps
    end
    add_index :billing_notifications, %i[account_id kind key], unique: true

    add_column :account_users, :billing_usage_emails, :boolean, null: false, default: true
  end
end

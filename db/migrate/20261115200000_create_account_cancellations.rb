class CreateAccountCancellations < ActiveRecord::Migration[7.1]
  def change
    create_table :account_cancellations do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :stripe_subscription_id, null: false
      t.string :reason, null: false
      t.text :feature
      t.string :outcome, null: false, default: 'started'
      t.jsonb :details, null: false, default: {}
      t.timestamps
    end
    add_index :account_cancellations, :account_id, unique: true, where: "outcome = 'discounted'", name: 'one_retention_discount_per_account'
  end
end

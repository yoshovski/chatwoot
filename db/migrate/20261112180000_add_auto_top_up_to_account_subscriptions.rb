class AddAutoTopUpToAccountSubscriptions < ActiveRecord::Migration[7.2]
  def change
    change_table :account_subscriptions, bulk: true do |t|
      t.boolean :auto_top_up_enabled, default: false, null: false
      t.integer :auto_top_up_max_packs, default: 1, null: false
      # Packs started automatically in the quota period that began at auto_top_up_period_start (the monthly ceiling).
      t.datetime :auto_top_up_period_start
      t.integer :auto_top_up_count, default: 0, null: false
      # Set while an automatic payment is on its way to the webhook, so a second reply does not start a second pack.
      t.datetime :auto_top_up_pending_at
      t.datetime :auto_top_up_failed_at
    end
  end
end

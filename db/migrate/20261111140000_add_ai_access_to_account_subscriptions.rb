# The AI limit now applies in every subscription state. Accounts that exist today were all set up by hand in
# Super Admin, so they are marked as manual accounts and keep AI replies exactly as before.
class AddAiAccessToAccountSubscriptions < ActiveRecord::Migration[7.2]
  def up
    add_column :account_subscriptions, :manual_ai_access, :boolean, default: false, null: false
    add_column :account_subscriptions, :past_due_since, :datetime

    execute <<~SQL.squish
      UPDATE account_subscriptions SET manual_ai_access = TRUE WHERE payment_status = 'manual'
    SQL
    execute <<~SQL.squish
      INSERT INTO account_subscriptions (account_id, manual_ai_access, quota_anchor, created_at, updated_at)
      SELECT accounts.id, TRUE, NOW(), NOW(), NOW() FROM accounts
      WHERE NOT EXISTS (SELECT 1 FROM account_subscriptions WHERE account_subscriptions.account_id = accounts.id)
    SQL
    execute <<~SQL.squish
      UPDATE account_subscriptions SET past_due_since = updated_at WHERE payment_status = 'past_due'
    SQL
  end

  def down
    remove_column :account_subscriptions, :past_due_since
    remove_column :account_subscriptions, :manual_ai_access
  end
end

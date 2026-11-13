# Per-user opt-out for the first-week emails (T15): the unsubscribe link in each of them turns this off.
class AddOnboardingEmailsToAccountUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :account_users, :onboarding_emails, :boolean, null: false, default: true
  end
end

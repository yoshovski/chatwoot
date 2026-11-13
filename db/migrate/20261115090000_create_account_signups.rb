# One row per public signup (T11): consent, where it came from and whether it got the trial. The row outlives the
# account (account_id is nulled on delete) so deleting an account and signing up again does not earn a second trial.
class CreateAccountSignups < ActiveRecord::Migration[7.1]
  def change # rubocop:disable Metrics/MethodLength
    create_table :account_signups do |t|
      t.references :account, index: { unique: true }
      t.references :user
      t.string :email
      t.string :email_domain
      t.string :website_domain
      t.string :ip
      t.string :signup_method, null: false, default: 'email'
      t.string :terms_version
      t.string :privacy_version
      t.datetime :consented_at
      t.boolean :trial_granted, null: false, default: false
      t.string :trial_refused_reason
      t.datetime :trial_override_at
      t.datetime :welcome_sent_at
      t.timestamps
    end
    add_index :account_signups, :email_domain
    add_index :account_signups, :website_domain
    add_index :account_signups, :ip
    add_index :account_signups, :created_at
  end
end

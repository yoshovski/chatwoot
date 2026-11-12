# One row per billing email the account's administrators were sent (T08). The unique (account, kind, key) is what
# makes every email go out once: a trial end, a quota period, a failed invoice, a top-up each have their own key.
class BillingNotification < ApplicationRecord
  belongs_to :account

  validates :kind, :key, presence: true

  # Records the email and returns true, or false when it was already sent. ON CONFLICT instead of a rescued unique
  # violation, so a caller inside a transaction is not left with an aborted one.
  def self.claim(account, kind, key)
    now = Time.current
    # rubocop:disable Rails/SkipsModelValidations
    insert({ account_id: account.id, kind: kind, key: key.to_s, created_at: now, updated_at: now },
           unique_by: %i[account_id kind key], returning: :id).rows.any?
    # rubocop:enable Rails/SkipsModelValidations
  end

  def self.sent?(account, kind, key)
    exists?(account: account, kind: kind, key: key.to_s)
  end
end

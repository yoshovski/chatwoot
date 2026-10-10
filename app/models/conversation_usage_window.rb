class ConversationUsageWindow < ApplicationRecord
  belongs_to :account
  belongs_to :conversation, optional: true
  belongs_to :message, optional: true

  def self.record(message)
    return unless message.incoming? && !message.private?

    # Lock the account so first-use creation and concurrent inbox messages share one serialization point.
    account = Account.find(message.account_id)
    account.with_lock do
      subscription = account.account_subscription || account.create_account_subscription!(quota_anchor: Time.current)
      windows = account.conversation_usage_windows.where(conversation_id: message.conversation_id)
      return if windows.exists?(['ends_at > ?', message.created_at])

      windows.create!(message: message, started_at: message.created_at, ends_at: message.created_at + 24.hours,
                      quota_period_start: subscription.quota_period(at: message.created_at).first)
    end
  end
end

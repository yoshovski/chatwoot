class ConversationUsageWindow < ApplicationRecord
  belongs_to :account
  belongs_to :conversation, optional: true
  belongs_to :message, optional: true
  has_one :extra_ai_conversation_entry, dependent: :nullify

  # One window is one "AI conversation". It opens when the AI agent (Captain assistant or agent bot) actually replies,
  # and lasts 24 hours. A conversation only a person answers, one blocked at the limit (the reply is never saved) and
  # playground test runs (no message is saved) open none. Inside the plan allowance the window is included; beyond
  # it, it takes one extra AI conversation from the balance.
  def self.record(message)
    return unless message.ai_reply?

    # Lock the account so first-use creation, concurrent replies and the extra balance share one serialization point.
    account = Account.find(message.account_id)
    subscription = account.with_lock { open_window(account, message) }
    # After the lock is released, so the job sees the new window.
    return unless subscription

    subscription.request_auto_top_up
    # The 80 % and 100 % usage emails (T08).
    Billing::NotificationsJob.perform_later(account.id) if Billing::NotificationsService.new(subscription).usage_notice_pending?
  end

  # Returns the subscription when a window opened, nil when the conversation already had one.
  def self.open_window(account, message)
    subscription = account.account_subscription || account.create_account_subscription!(quota_anchor: Time.current)
    windows = account.conversation_usage_windows.where(conversation_id: message.conversation_id)
    return if windows.exists?(['ends_at > ?', message.created_at])

    beyond_allowance = !subscription.allowance_left?
    window = windows.create!(message: message, started_at: message.created_at, ends_at: message.created_at + 24.hours,
                             quota_period_start: subscription.quota_period(at: message.created_at).first)
    window.update!(extra: true) if beyond_allowance && ExtraAiConversationEntry.use!(window)
    subscription
  end
  private_class_method :open_window
end

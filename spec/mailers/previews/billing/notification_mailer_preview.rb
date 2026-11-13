# Previews of the billing emails (T08) at /rails/mailers/billing/notification_mailer. They use the first account with
# an administrator in the local database.
class Billing::NotificationMailerPreview < ActionMailer::Preview
  {
    trial_ending_3: { 'ends_at' => 3.days.from_now, 'plan' => 'Growth' },
    trial_ending_3_paid: ['trial_ending_3', { 'ends_at' => 3.days.from_now, 'plan' => 'Growth', 'paid_next' => true,
                                              'amount' => { 'cents' => 4900, 'currency' => 'eur' } }],
    trial_ending_1: { 'ends_at' => 1.day.from_now, 'plan' => 'Growth' },
    trial_ended: { 'plan' => 'Free', 'ai_limit' => 0 },
    usage_80: { 'used' => 40, 'limit' => 50, 'resets_at' => 12.days.from_now },
    usage_80_trial: ['usage_80', { 'used' => 40, 'limit' => 50, 'trial' => true }],
    usage_100: { 'used' => 50, 'limit' => 50, 'resets_at' => 12.days.from_now, 'can_top_up' => true },
    usage_100_trial: ['usage_100', { 'used' => 50, 'limit' => 50, 'trial' => true }],
    payment_failed_0: { 'plan' => 'Growth', 'pauses_at' => 7.days.from_now },
    payment_failed_3: { 'plan' => 'Growth', 'pauses_at' => 4.days.from_now },
    payment_failed_6: { 'plan' => 'Growth', 'pauses_at' => 1.day.from_now },
    payment_paused: {},
    annual_renewal: { 'plan' => 'Growth', 'renews_at' => 7.days.from_now, 'amount' => { 'cents' => 47_000, 'currency' => 'eur' } },
    top_up_receipt: { 'count' => 50, 'expires_at' => 12.months.from_now },
    auto_top_up_off: {},
    cancellation_confirmed: { 'plan' => 'Growth', 'ends_at' => 20.days.from_now },
    win_back: {}
  }.each do |name, (kind, meta)|
    if kind.is_a?(Hash)
      meta = kind
      kind = name.to_s
    end
    define_method(name) do
      account_user = AccountUser.administrator.first!
      Billing::NotificationMailer.with(account: account_user.account).notify(account_user, kind, meta)
    end
  end
end

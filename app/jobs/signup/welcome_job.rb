# Sends a confirmed public signup its welcome email, once (account_signups.welcome_sent_at). The welcome is day 0 of the
# first-week emails (T15); days 1, 3 and 7 count from welcome_sent_at (Onboarding::FirstWeekEmailsService).
class Signup::WelcomeJob < ApplicationJob
  queue_as :mailers

  def perform(account_signup)
    account_user = account_signup.account&.account_users&.find_by(user_id: account_signup.user_id)
    return if account_user.nil?

    # Claimed in one statement, so two confirmations (or a retry) send one email.
    claimed = AccountSignup.where(id: account_signup.id, welcome_sent_at: nil).update_all(welcome_sent_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    return unless claimed == 1

    Onboarding::FirstWeekMailer.with(account: account_signup.account).notify(account_user, 'onboarding_day_0').deliver_now
  end
end

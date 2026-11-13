# Sends a confirmed public signup its welcome email, once (account_signups.welcome_sent_at).
class Signup::WelcomeJob < ApplicationJob
  queue_as :mailers

  def perform(account_signup)
    return if account_signup.account.nil? || account_signup.user.nil?

    # Claimed in one statement, so two confirmations (or a retry) send one email.
    claimed = AccountSignup.where(id: account_signup.id, welcome_sent_at: nil).update_all(welcome_sent_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    return unless claimed == 1

    Signup::WelcomeMailer.with(account: account_signup.account).welcome(account_signup.user).deliver_now
  end
end

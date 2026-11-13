# Preview of the welcome email after signup (T11) at /rails/mailers/signup/welcome_mailer. Uses the first account with
# an administrator in the local database.
class Signup::WelcomeMailerPreview < ActionMailer::Preview
  def welcome
    account_user = AccountUser.where(role: :administrator).first
    Signup::WelcomeMailer.with(account: account_user.account).welcome(account_user.user)
  end
end

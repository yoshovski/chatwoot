# The welcome email after a public signup is confirmed (T11), with one next step. Copy: signup_emails in en.yml.
# The day-0 email of T15 can replace it.
class Signup::WelcomeMailer < ApplicationMailer
  def welcome(user)
    return unless smtp_config_set_or_development?

    @recipient = user
    locale = Billing::NotificationMailer.copy_locale(user.ui_settings&.dig('locale').presence || I18n.locale.to_s)
    locale = :en unless I18n.exists?('signup_emails.welcome.subject', locale, fallback: false)
    I18n.with_locale(locale) { send_mail_with_liquid(to: user.email, subject: t('signup_emails.welcome.subject', brand: brand_name)) }
  end

  private

  def brand_name
    GlobalConfig.get('BRAND_NAME')['BRAND_NAME'].presence || 'ChatOctave'
  end

  def liquid_locals
    super.merge(
      heading: t('signup_emails.welcome.subject', brand: brand_name), greeting: t('signup_emails.welcome.greeting', name: @recipient.available_name),
      body: t('signup_emails.welcome.body'), button_text: t('signup_emails.welcome.button'),
      button_url: "#{ENV.fetch('FRONTEND_URL', nil)}/app/accounts/#{Current.account.id}/dashboard"
    )
  end
end

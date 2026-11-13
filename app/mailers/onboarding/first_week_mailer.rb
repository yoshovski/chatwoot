# The first-week emails (T15) to the person who signed up: day 0 (the welcome), 1, 3 and 7, each with one next step
# and an unsubscribe link. Onboarding::FirstWeekEmailsService decides what is due; this only words it.
# Copy: onboarding_emails in en.yml.
class Onboarding::FirstWeekMailer < ApplicationMailer
  OPT_OUT_PURPOSE = :onboarding_emails
  KINDS = %w[onboarding_day_0 onboarding_day_1 onboarding_day_3 onboarding_day_7].freeze

  # The language to write in: the one asked for when its copy exists, otherwise English (also the opt-out page).
  def self.copy_locale(locale)
    available = I18n.available_locales.map(&:to_s).include?(locale.to_s)
    available && I18n.exists?('onboarding_emails.greeting', locale, fallback: false) ? locale : :en
  end

  def notify(account_user, kind, meta = {})
    raise ArgumentError, "unknown first-week email #{kind}" unless KINDS.include?(kind)
    return unless smtp_config_set_or_development?

    @kind = kind
    @meta = meta.stringify_keys
    @recipient = account_user.user
    @opt_out_url = opt_out_url(account_user)
    headers['List-Unsubscribe'] = "<#{@opt_out_url}>"
    headers['List-Unsubscribe-Post'] = 'List-Unsubscribe=One-Click'

    I18n.with_locale(recipient_locale) { send_mail_with_liquid(to: @recipient.email, subject: copy('subject')) }
  end

  private

  def recipient_locale
    self.class.copy_locale(@recipient.ui_settings&.dig('locale').presence || I18n.locale.to_s)
  end

  def liquid_locals
    super.merge(
      heading: copy('subject'), greeting: t('onboarding_emails.greeting', name: @recipient.available_name),
      body: copy(body_key), questions: @meta['questions'], code: @meta['script'],
      button_text: copy('button'), button_url: button_url,
      opt_out_url: @opt_out_url, opt_out_text: t('onboarding_emails.opt_out')
    )
  end

  def body_key
    return 'body' unless @kind == 'onboarding_day_7'
    return 'body_none' if @meta['used'].to_i.zero?

    @meta['limit'] ? 'body_capped' : 'body'
  end

  def copy(part)
    t("onboarding_emails.#{@kind.delete_prefix('onboarding_')}.#{part}",
      brand: brand_name, count: @meta['count'] || @meta['used'], used: @meta['used'], limit: @meta['limit'], date: date)
  end

  def brand_name
    GlobalConfig.get('BRAND_NAME')['BRAND_NAME'].presence || 'ChatOctave'
  end

  def date
    return unless @meta['ends_at']

    day = @meta['ends_at'].to_time.in_time_zone.to_date
    t('billing_emails.date_format', day: day.day, month: t('billing_emails.month_names')[day.month - 1], year: day.year)
  end

  def button_url
    base = "#{ENV.fetch('FRONTEND_URL', nil)}/app/accounts/#{Current.account.id}"
    case @kind
    when 'onboarding_day_0' then "#{base}/home/setup/test_agent"
    when 'onboarding_day_1' then "#{base}/home/setup/chat_widget"
    when 'onboarding_day_3' then @meta['assistant_id'] ? "#{base}/captain/#{@meta['assistant_id']}/faqs/suggestions" : "#{base}/home"
    else "#{base}/settings/billing"
    end
  end

  def opt_out_url(account_user)
    token = account_user.signed_id(purpose: OPT_OUT_PURPOSE)
    "#{ENV.fetch('FRONTEND_URL', nil)}/onboarding_emails/opt_out?token=#{CGI.escape(token)}"
  end
end

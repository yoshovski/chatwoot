# Billing emails to an account's administrators (T08): one per recipient, so the usage emails can carry that person's
# own opt-out link. Billing::NotificationsService decides what is due; this only words it. Copy: billing_emails in en.yml.
class Billing::NotificationMailer < ApplicationMailer
  OPT_OUT_PURPOSE = :billing_usage_emails

  def notify(account_user, kind, meta)
    return unless smtp_config_set_or_development?

    @kind = kind
    @meta = meta
    @recipient = account_user.user
    @opt_out_url = opt_out_url(account_user) if Billing::NotificationsService::USAGE_KINDS.include?(kind)
    headers['List-Unsubscribe'] = "<#{@opt_out_url}>" if @opt_out_url
    headers['List-Unsubscribe-Post'] = 'List-Unsubscribe=One-Click' if @opt_out_url

    I18n.with_locale(recipient_locale) { send_mail_with_liquid(to: @recipient.email, subject: copy('subject')) }
  end

  private

  # The recipient's own language (Profile), then the account's, then English (ApplicationMailer#switch_locale).
  def recipient_locale
    locale = @recipient.ui_settings&.dig('locale')
    I18n.available_locales.map(&:to_s).include?(locale) ? locale : I18n.locale
  end

  def liquid_locals
    super.merge(
      heading: copy('subject'), greeting: t('billing_emails.greeting', name: @recipient.available_name),
      body: copy(body_key), button_text: copy(button_key), button_url: billing_url, footnote: footnote, usage_percent: usage_percent,
      opt_out_url: @opt_out_url, opt_out_text: (t('billing_emails.usage_opt_out') if @opt_out_url)
    )
  end

  def body_key
    return 'body_trial' if @meta['trial']
    return 'body_paid' if @meta['paid_next'] && @meta['amount']
    return 'body_with_ai' if @kind == 'trial_ended' && @meta['ai_limit'].to_i.positive?

    'body'
  end

  def button_key
    return 'button_paid' if body_key == 'body_paid'

    @kind == 'usage_100' && !@meta['can_top_up'] ? 'button_plans' : 'button'
  end

  def usage_percent
    [(@meta['used'].to_f / @meta['limit'] * 100).round, 100].min if @meta['used'] && @meta['limit'].to_i.positive?
  end

  # Emails about a coming charge say where the plan is managed, quietly, under the button.
  def footnote
    t('billing_emails.plan_footnote') if @kind == 'annual_renewal' || body_key == 'body_paid'
  end

  def copy(part)
    t("billing_emails.#{@kind}.#{part}",
      plan: @meta['plan'], used: @meta['used'], limit: @meta['limit'] || @meta['ai_limit'], count: @meta['count'],
      amount: amount, date: date)
  end

  def date
    at = @meta.values_at('ends_at', 'resets_at', 'pauses_at', 'renews_at', 'expires_at').compact.first
    at.to_time.in_time_zone.strftime('%-d %B %Y') if at
  end

  def amount
    money = @meta['amount']
    return unless money

    format('%<value>.2f %<currency>s', value: money['cents'].to_i / 100.0, currency: money['currency'].to_s.upcase)
  end

  def billing_url
    "#{ENV.fetch('FRONTEND_URL', nil)}/app/accounts/#{Current.account.id}/settings/billing"
  end

  def opt_out_url(account_user)
    token = account_user.signed_id(purpose: OPT_OUT_PURPOSE)
    "#{ENV.fetch('FRONTEND_URL', nil)}/billing_emails/usage_opt_out?token=#{CGI.escape(token)}"
  end
end

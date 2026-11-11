# Billing alerts for the instance (Super Admin), not for the account's own administrators.
class AdministratorNotifications::BillingAlertMailer < AdministratorNotifications::BaseMailer
  def dispute_created(account, details)
    return if instance_admin_email.blank?

    meta = details.to_h.stringify_keys.merge(
      'account_id' => account.id, 'account_name' => account.name,
      'amount' => format('%<amount>.2f %<currency>s', amount: details[:amount_cents].to_i / 100.0, currency: details[:currency].to_s.upcase),
      'super_admin_url' => "#{ENV.fetch('FRONTEND_URL', '')}/super_admin/accounts/#{account.id}"
    )
    send_notification("Payment dispute on account #{account.id}: AI paused", to: instance_admin_email, meta: meta)
  end

  private

  def instance_admin_email
    GlobalConfig.get('CHATWOOT_INSTANCE_ADMIN_EMAIL')['CHATWOOT_INSTANCE_ADMIN_EMAIL']
  end
end

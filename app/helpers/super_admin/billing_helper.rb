module SuperAdmin::BillingHelper
  def billing_money(cents, currency)
    return '—' if cents.nil?

    "#{format('%.2f', cents / 100.0)} #{currency.to_s.upcase}"
  end

  def billing_time(value)
    return '—' if value.blank?

    time = value.is_a?(String) ? Time.zone.parse(value) : value
    time.utc.strftime('%Y-%m-%d %H:%M UTC')
  end
end

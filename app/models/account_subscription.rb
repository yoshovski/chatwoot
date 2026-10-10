class AccountSubscription < ApplicationRecord
  SUPPORTED_CURRENCIES = %w[eur usd gbp brl].freeze
  PRICE_FIELDS = %w[monthly_price annual_price setup_fee custom_payment].freeze
  PRICE_FORMAT = /\A\d+(?:[.,]\d{1,2})?\z/
  CONFIGURATION_FIELDS = %w[enabled monthly_limit billing_interval currency monthly_price annual_price annual_discount_percent
                            setup_fee custom_payment custom_payment_description new_custom_payment trial_enabled trial_days
                            trial_ends_at period_started_at period_ends_at reset_usage].freeze
  belongs_to :account
  attr_accessor :reset_usage, :new_custom_payment

  validates :billing_interval, inclusion: { in: %w[month year] }
  validates :currency, inclusion: { in: SUPPORTED_CURRENCIES }
  validates :monthly_limit, :annual_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :monthly_price_cents, :setup_fee_cents, :custom_payment_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :annual_discount_percent, numericality: { only_integer: true, in: 0..100 }
  validates :trial_days, numericality: { only_integer: true, in: 1..730 }
  validate :validate_period_dates
  validate :validate_price_inputs
  before_validation :initialize_dates
  before_validation :initialize_trial
  before_validation :initialize_custom_payment

  PRICE_FIELDS.each do |name|
    define_method(name) do
      return instance_variable_get("@#{name}") if instance_variable_defined?("@#{name}")

      cents = public_send("#{name}_cents")
      format('%<units>d.%<fraction>02d', units: cents / 100, fraction: cents % 100) unless cents.nil?
    end

    define_method("#{name}=") do |value|
      amount = value.to_s.strip
      instance_variable_set("@#{name}", amount)
      if name == 'annual_price' && amount.blank?
        self.annual_price_cents = nil
      elsif PRICE_FORMAT.match?(amount)
        public_send("#{name}_cents=", (BigDecimal(amount.tr(',', '.')) * 100).to_i)
      end
    end
  end

  def quota_period(at: Time.current)
    anchor = quota_anchor || Time.current
    months = [((at.year - anchor.year) * 12) + at.month - anchor.month, 0].max
    months -= 1 if months.positive? && anchor.advance(months: months) > at
    [anchor.advance(months: months), anchor.advance(months: months + 1)]
  end

  def consumed(at: Time.current)
    account.conversation_usage_windows.where(quota_period_start: quota_period(at: at).first).count
  end

  def trial_active?
    enabled? && trial_enabled? && %w[active manual].exclude?(payment_status)
  end

  def ai_reply_allowed?(conversation = nil)
    return true unless trial_active?
    return false unless trial_ends_at && trial_ends_at > Time.current
    return true if monthly_limit.nil?

    period = quota_period.first
    window = conversation && account.conversation_usage_windows.where(conversation: conversation).where('ends_at > ?', Time.current).last
    return consumed < monthly_limit unless window

    # The final allowed conversation may finish its 24-hour window. A new window beyond the quota cannot reply.
    account.conversation_usage_windows.where(quota_period_start: period).where('(started_at, id) <= (?, ?)', window.started_at,
                                                                               window.id).count <= monthly_limit
  end

  def annual_amount_cents
    annual_price_cents || (monthly_price_cents * 12 * (100 - annual_discount_percent) / 100.0).round
  end

  def summary
    usage_summary.merge(pricing_summary)
  end

  def pricing_summary
    slice(:enabled, :billing_interval, :currency, :monthly_price_cents, :annual_discount_percent, :setup_fee_cents,
          :period_started_at, :period_ends_at, :payment_status).symbolize_keys.merge(
            annual_price_cents: annual_amount_cents, trial_enabled: trial_active?, trial_ends_at: trial_ends_at,
            can_checkout: enabled? && (stripe_subscription_id.blank? || payment_status == 'canceled') && monthly_price_cents.positive?,
            can_manage: stripe_customer_id.present?, custom_payment_cents: custom_payment_cents,
            custom_payment_description: custom_payment_description,
            can_pay_customization: enabled? && custom_payment_cents.positive? && custom_payment_paid_at.blank?
          )
  end

  def usage_summary
    start_at, end_at = quota_period
    usage = consumed
    {
      enabled: enabled, monthly_limit: monthly_limit, consumed: usage, quota_started_at: start_at, quota_resets_at: end_at,
      ai_replies_paused: !ai_reply_allowed?, warning: !monthly_limit.nil? && (monthly_limit.zero? || usage >= monthly_limit * 0.8),
      history: account.conversation_usage_windows.group(:quota_period_start).order(quota_period_start: :desc).limit(12).count.map do |period, count|
        { period_started_at: period, consumed: count }
      end
    }
  end

  private

  def validate_price_inputs
    PRICE_FIELDS.each do |name|
      next unless instance_variable_defined?("@#{name}")

      amount = public_send(name)
      next if name == 'annual_price' && amount.blank?
      next if PRICE_FORMAT.match?(amount)

      errors.add(name, :invalid)
    end
  end

  def initialize_custom_payment
    return unless will_save_change_to_currency? || will_save_change_to_custom_payment_cents? || will_save_change_to_custom_payment_description? ||
                  ActiveModel::Type::Boolean.new.cast(new_custom_payment)

    self.custom_payment_revision = SecureRandom.uuid
    self.custom_payment_paid_at = nil
  end

  def initialize_dates
    self.quota_anchor ||= Time.current
    self.quota_anchor = Time.current if ActiveModel::Type::Boolean.new.cast(reset_usage)
  end

  def initialize_trial
    return unless trial_enabled?
    return unless will_save_change_to_trial_enabled? || trial_ends_at.blank?

    self.trial_ends_at ||= Time.current + trial_days.days
    self.payment_status = 'trialing' if stripe_subscription_id.blank?
  end

  def validate_period_dates
    return if period_started_at.blank? || period_ends_at.blank? || period_ends_at > period_started_at

    errors.add(:period_ends_at, :invalid)
  end
end

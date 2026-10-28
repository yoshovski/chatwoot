# A plan Super Admin sells to client accounts: included features, paid add-ons, limits, trial and display price.
# Accounts point at it through their subscription; their own subscription/limit fields override it when set.
class BillingPlan < ApplicationRecord
  # Only these flags are governed by plans. Every other feature flag stays per account.
  FEATURES = %w[captain_integration captain_integration_v2 native_ai_knowledge help_center campaigns reports
                channel_voice calls crm_integration shopify_integration disable_branding].freeze
  LIMIT_FIELDS = %w[ai_conversations_limit trial_ai_conversations_limit agents_limit inboxes_limit documents_limit].freeze

  has_many :account_subscriptions, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :currency, inclusion: { in: AccountSubscription::SUPPORTED_CURRENCIES }
  validates :monthly_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :trial_days, numericality: { only_integer: true, in: 1..730 }
  validates(*LIMIT_FIELDS, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true)
  validate :validate_features

  scope :ordered, -> { order(:position, :id) }

  after_update_commit :sync_accounts, if: -> { saved_change_to_features? || saved_change_to_add_ons? }

  # Super Admin form: { feature_key => 'included' | 'add_on' | '' } and { feature_key => price }, applied together
  # before validation so the order the form sends them in doesn't matter.
  attr_writer :feature_settings, :add_on_prices

  before_validation :apply_feature_settings

  def monthly_price
    format('%<units>d.%<fraction>02d', units: monthly_price_cents / 100, fraction: monthly_price_cents % 100)
  end

  def monthly_price=(value)
    self.monthly_price_cents = price_cents(value)
  end

  def feature_setting(key)
    return 'included' if features.include?(key)

    add_ons.key?(key) ? 'add_on' : ''
  end

  # The plan features this account should have: included ones plus the add-ons it bought.
  def enabled_features_for(subscription)
    features | (add_ons.keys & subscription.add_ons)
  end

  def summary(subscription)
    slice(:name, :description, :currency, :monthly_price_cents, :features).symbolize_keys.merge(
      add_ons: add_ons.map { |key, price| { key: key, price_cents: price, active: subscription.add_ons.include?(key) } }
    )
  end

  private

  def apply_feature_settings
    return if @feature_settings.nil?

    settings = @feature_settings.to_h.stringify_keys
    prices = @add_on_prices.to_h.stringify_keys
    self.features = FEATURES.select { |key| settings[key] == 'included' }
    self.add_ons = FEATURES.select { |key| settings[key] == 'add_on' }.index_with { |key| price_cents(prices[key]) }
  end

  def price_cents(value)
    amount = value.to_s.strip.tr(',', '.')
    amount.match?(/\A\d+(\.\d{1,2})?\z/) ? (BigDecimal(amount) * 100).to_i : 0
  end

  def sync_accounts
    account_subscriptions.includes(:account).find_each(&:sync_plan_features)
  end

  def validate_features
    errors.add(:features, :invalid) unless features.is_a?(Array) && (features - FEATURES).empty?
    errors.add(:add_ons, :invalid) unless add_ons.is_a?(Hash) && (add_ons.keys - FEATURES).empty? && !add_ons.keys.intersect?(features)
  end
end

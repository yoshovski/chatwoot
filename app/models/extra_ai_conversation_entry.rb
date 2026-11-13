# The ledger behind the extra AI conversation balance (T03). Each change is one row:
#   purchase   +n  a lot that expires 12 months after purchase (Stripe reference unique, so one payment credits once)
#   adjustment +n  a lot granted by a person (Super Admin, with a note saying why), same expiry
#   usage      -1  one AI conversation beyond the plan allowance, taken from the lot that expires first
#   expiry     -n  what was left of a lot when it expired
# The balance is what is left of the lots that have not expired, so it never depends on the expiry job having run.
class ExtraAiConversationEntry < ApplicationRecord
  CREDIT_REASONS = %w[purchase adjustment].freeze
  REASONS = (CREDIT_REASONS + %w[usage expiry]).freeze
  LIFETIME = 12.months

  belongs_to :account
  belongs_to :lot, class_name: 'ExtraAiConversationEntry', optional: true
  belongs_to :conversation_usage_window, optional: true
  belongs_to :user, optional: true

  validates :reason, inclusion: { in: REASONS }
  validates :amount, numericality: { only_integer: true, other_than: 0 }
  validates :stripe_reference, uniqueness: true, allow_nil: true
  validates :note, presence: true, if: -> { reason == 'adjustment' }
  validates :note, length: { maximum: 255 }

  # The top-up receipt email (T08).
  after_create_commit -> { Billing::NotificationsJob.perform_later(account_id) }, if: -> { reason == 'purchase' && stripe_reference.present? }

  scope :open_lots, -> { where(reason: CREDIT_REASONS).where('remaining > 0 AND expires_at > ?', Time.current) }

  def self.balance(account)
    where(account: account).open_lots.sum(:remaining)
  end

  # Adds a lot. Called again with the same Stripe reference, it returns the first row and credits nothing.
  def self.credit!(account:, amount:, reason: 'purchase', stripe_reference: nil, user: nil, note: nil) # rubocop:disable Metrics/ParameterLists
    raise ArgumentError, "#{reason} does not add to the balance" unless CREDIT_REASONS.include?(reason)

    existing = stripe_reference && find_by(stripe_reference: stripe_reference)
    return existing if existing

    create!(account: account, reason: reason, amount: amount, remaining: amount, expires_at: LIFETIME.from_now,
            stripe_reference: stripe_reference, user: user, note: note)
  rescue ActiveRecord::RecordNotUnique
    find_by!(stripe_reference: stripe_reference)
  end

  # Takes one conversation for the window from the lot that expires first. The caller holds the account lock.
  def self.use!(window)
    lot = where(account_id: window.account_id).open_lots.order(:expires_at, :id).lock.first
    return false unless lot

    lot.update!(remaining: lot.remaining - 1)
    create!(account_id: window.account_id, reason: 'usage', amount: -1, lot_id: lot.id, conversation_usage_window_id: window.id)
  end

  # Writes an expiry row for every lot that expired with conversations left. Run daily by ExpireExtraAiConversationsJob.
  def self.expire!
    where(reason: CREDIT_REASONS).where('remaining > 0 AND expires_at <= ?', Time.current).find_each do |lot|
      Account.find(lot.account_id).with_lock do
        lot.reload
        next unless lot.remaining.positive?

        create!(account_id: lot.account_id, reason: 'expiry', amount: -lot.remaining, lot_id: lot.id)
        lot.update!(remaining: 0)
      end
    end
  end
end

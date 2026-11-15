# A cancellation attempt and its final decision. Retention discounts are unique per account, across subscriptions.
# == Schema Information
#
# Table name: account_cancellations
#
#  id                     :bigint           not null, primary key
#  details                :jsonb            not null
#  feature                :text
#  outcome                :string           default("started"), not null
#  reason                 :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  stripe_subscription_id :string           not null
#  user_id                :bigint
#
# Indexes
#
#  index_account_cancellations_on_account_id  (account_id)
#  index_account_cancellations_on_user_id     (user_id)
#  one_retention_discount_per_account         (account_id) UNIQUE WHERE ((outcome)::text = 'discounted'::text)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => nullify
#
class AccountCancellation < ApplicationRecord
  REASONS = %w[expensive unused feature quality other].freeze
  OUTCOMES = %w[started canceled discounted paused downgraded setup_requested kept resumed].freeze
  belongs_to :account
  belongs_to :user, optional: true
  validates :reason, inclusion: { in: REASONS }
  validates :outcome, inclusion: { in: OUTCOMES }
  validates :feature, length: { maximum: 2000 }
  after_update_commit :schedule_resume, if: -> { saved_change_to_outcome? && outcome == 'paused' }

  private

  def schedule_resume
    Enterprise::Billing::ResumeCollectionJob.set(wait_until: Time.zone.at(details.fetch('resumes_at'))).perform_later(account_id,
                                                                                                                      stripe_subscription_id)
  end
end

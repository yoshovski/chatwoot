# == Schema Information
#
# Table name: stripe_events
#
#  id                 :bigint           not null, primary key
#  attempts           :integer          default(0), not null
#  error              :text
#  event_type         :string           not null
#  payload            :jsonb            not null
#  processed_at       :datetime
#  status             :string           default("received"), not null
#  stripe_created_at  :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  stripe_customer_id :string
#  stripe_id          :string           not null
#
# Indexes
#
#  index_stripe_events_on_status_and_created_at              (status,created_at)
#  index_stripe_events_on_stripe_customer_id_and_created_at  (stripe_customer_id,created_at)
#  index_stripe_events_on_stripe_id                          (stripe_id) UNIQUE
#
# One row per Stripe webhook event. The controller stores it, Enterprise::Billing::ProcessStripeEventJob handles it
# once, and Enterprise::Billing::ReplayStripeEventService can run a stored event again.
class StripeEvent < ApplicationRecord
  STATUSES = %w[received processed failed ignored].freeze

  validates :stripe_id, presence: true, uniqueness: true
  validates :event_type, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :failed, -> { where(status: 'failed') }
  scope :for_customer, ->(customer_id) { where(stripe_customer_id: customer_id) }

  def self.record!(event)
    payload = event.to_hash
    object = payload.dig(:data, :object) || {}
    create!(
      stripe_id: event.id, event_type: event.type, payload: payload,
      stripe_created_at: event.created ? Time.zone.at(event.created) : nil,
      stripe_customer_id: object[:object] == 'customer' ? object[:id] : object[:customer].presence
    )
  end

  def stripe_event
    Stripe::Event.construct_from(payload.deep_symbolize_keys)
  end

  def processed?
    status == 'processed'
  end

  def mark_processed!(status = 'processed')
    update!(status: status, error: nil, processed_at: Time.current)
  end

  def mark_failed!(exception, attempts: self.attempts)
    update!(status: 'failed', attempts: attempts, error: "#{exception.class}: #{exception.message}".truncate(2000))
  end
end

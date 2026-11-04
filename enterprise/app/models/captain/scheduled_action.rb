# == Schema Information
#
# Table name: captain_scheduled_actions
#
#  id              :bigint           not null, primary key
#  attempts        :integer          default(0), not null
#  cancel_on       :jsonb            not null
#  cancel_reason   :string
#  cancelled_at    :datetime
#  dedupe_key      :string
#  due_at          :datetime         not null
#  executed_at     :datetime
#  kind            :string           not null
#  last_error      :text
#  payload         :jsonb            not null
#  status          :string           default("pending"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  assistant_id    :bigint           not null
#  conversation_id :bigint           not null
#
# Indexes
#
#  idx_captain_scheduled_actions_pending_dedupe            (conversation_id,kind,dedupe_key) UNIQUE WHERE ((status)::text = 'pending'::text)
#  index_captain_scheduled_actions_on_account_id           (account_id)
#  index_captain_scheduled_actions_on_assistant_id         (assistant_id)
#  index_captain_scheduled_actions_on_conversation_id      (conversation_id)
#  index_captain_scheduled_actions_on_status_and_due_at    (status,due_at)
#
# Foreign Keys
#
#  fk_rails_120a94eb2b  (conversation_id => conversations.id) ON DELETE => cascade
#

# Something the AI agent does later in one conversation, such as a follow-up message. See Captain::ScheduledActions.
class Captain::ScheduledAction < ApplicationRecord
  self.table_name = 'captain_scheduled_actions'

  KINDS = %w[follow_up_message follow_up_email].freeze
  CANCEL_REASONS = %w[visitor_message human_message resolved handoff].freeze
  MAX_PENDING_PER_CONVERSATION = 3
  MAX_PAYLOAD_BYTES = 10.kilobytes
  MAX_ATTEMPTS = 3
  FINISHED_STATUSES = %w[done cancelled failed].freeze

  belongs_to :account
  belongs_to :conversation, class_name: '::Conversation'
  belongs_to :assistant, class_name: 'Captain::Assistant'

  enum :status, { pending: 'pending', running: 'running', done: 'done', cancelled: 'cancelled', failed: 'failed' }

  validates :kind, inclusion: { in: KINDS }
  validates :due_at, presence: true
  validate :payload_within_limit
  validate :cancel_on_known
  validate :pending_limit, on: :create

  scope :due, -> { pending.where(due_at: ..Time.current) }
  scope :finished, -> { where(status: FINISHED_STATUSES) }
  scope :cancellable_by, ->(reason) { pending.where('cancel_on ? :reason', reason: reason) }

  def cancels_on?(reason) = Array(cancel_on).include?(reason)

  private

  def payload_within_limit
    errors.add(:payload, 'is too large') if payload.to_json.bytesize > MAX_PAYLOAD_BYTES
  end

  def cancel_on_known
    errors.add(:cancel_on, 'contains an unknown reason') unless Array(cancel_on).all? { |reason| CANCEL_REASONS.include?(reason) }
  end

  def pending_limit
    return unless pending? && conversation_id

    count = self.class.pending.where(conversation_id: conversation_id).count
    errors.add(:base, "at most #{MAX_PENDING_PER_CONVERSATION} actions can wait in one conversation") if count >= MAX_PENDING_PER_CONVERSATION
  end
end

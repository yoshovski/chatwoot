# == Schema Information
#
# Table name: captain_knowledge_gaps
#
#  id                  :bigint           not null, primary key
#  classified_at       :datetime
#  draft_answer        :text
#  embedding           :vector(1536)
#  intent              :string(40)
#  kind                :integer          default("unclassified"), not null
#  language            :string(10)
#  last_seen_at        :datetime         not null
#  normalized_question :string           not null
#  occurrences_count   :integer          default(0), not null
#  question            :string(500)      not null
#  status              :integer          default("open"), not null
#  topic               :string(120)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  assistant_id        :bigint           not null
#  response_id         :bigint
#
# Indexes
#
#  idx_captain_knowledge_gaps_kind                     (assistant_id,kind,status)
#  idx_captain_knowledge_gaps_listing                  (account_id,assistant_id,status,last_seen_at)
#  idx_on_assistant_id_normalized_question_8e596bcf5e  (assistant_id,normalized_question) UNIQUE
#  index_captain_knowledge_gaps_on_account_id          (account_id)
#
class Captain::KnowledgeGap < ApplicationRecord
  self.table_name = 'captain_knowledge_gaps'

  QUESTION_LIMIT = 500
  # What a customer asked the AI to do. Counted per intent, never shown as an unanswered question.
  INTENTS = %w[order_status cancel return booking other].freeze
  # A knowledge gap is worth showing once this many conversations asked it, or once one of them ended in a handoff.
  MIN_CONVERSATIONS = 2

  belongs_to :account
  belongs_to :assistant, class_name: 'Captain::Assistant'
  belongs_to :response, class_name: 'Captain::AssistantResponse', optional: true
  has_many :occurrences, class_name: 'Captain::KnowledgeGapOccurrence', dependent: :delete_all, inverse_of: :knowledge_gap

  enum :status, { open: 0, answered: 1, dismissed: 2 }
  # unclassified until Captain::KnowledgeGaps::ClassifyJob has rewritten it.
  enum :kind, { unclassified: 0, knowledge: 1, action_request: 2, personal: 3, off_topic: 4 }

  has_neighbors :embedding, normalize: true

  validates :question, :normalized_question, :last_seen_at, presence: true
  validates :question, length: { maximum: QUESTION_LIMIT }
  validates :intent, inclusion: { in: INTENTS }, allow_nil: true

  before_validation :ensure_account

  scope :ordered, -> { order(occurrences_count: :desc, last_seen_at: :desc) }
  # The Unanswered list: open knowledge questions with enough evidence.
  scope :unanswered, lambda {
    handed_off = Captain::KnowledgeGapOccurrence.where(reason: 'handoff').where('knowledge_gap_id = captain_knowledge_gaps.id')
    open.knowledge.where(occurrences_count: MIN_CONVERSATIONS..).or(open.knowledge.where(handed_off.arel.exists))
  }

  private

  def ensure_account
    self.account = assistant&.account
  end
end

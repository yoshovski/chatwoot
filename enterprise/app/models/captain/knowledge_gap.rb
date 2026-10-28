# == Schema Information
#
# Table name: captain_knowledge_gaps
#
#  id                  :bigint           not null, primary key
#  last_seen_at        :datetime         not null
#  normalized_question :string           not null
#  occurrences_count   :integer          default(0), not null
#  question            :string(500)      not null
#  status              :integer          default("open"), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  assistant_id        :bigint           not null
#  response_id         :bigint
#
# Indexes
#
#  idx_captain_knowledge_gaps_listing                  (account_id,assistant_id,status,last_seen_at)
#  idx_on_assistant_id_normalized_question_8e596bcf5e  (assistant_id,normalized_question) UNIQUE
#  index_captain_knowledge_gaps_on_account_id          (account_id)
#
class Captain::KnowledgeGap < ApplicationRecord
  self.table_name = 'captain_knowledge_gaps'

  QUESTION_LIMIT = 500

  belongs_to :account
  belongs_to :assistant, class_name: 'Captain::Assistant'
  belongs_to :response, class_name: 'Captain::AssistantResponse', optional: true
  has_many :occurrences, class_name: 'Captain::KnowledgeGapOccurrence', dependent: :delete_all, inverse_of: :knowledge_gap

  enum :status, { open: 0, answered: 1, dismissed: 2 }

  validates :question, :normalized_question, :last_seen_at, presence: true
  validates :question, length: { maximum: QUESTION_LIMIT }

  before_validation :ensure_account

  scope :ordered, -> { order(occurrences_count: :desc, last_seen_at: :desc) }

  private

  def ensure_account
    self.account = assistant&.account
  end
end

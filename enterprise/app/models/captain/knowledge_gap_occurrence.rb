# == Schema Information
#
# Table name: captain_knowledge_gap_occurrences
#
#  id               :bigint           not null, primary key
#  reason           :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  conversation_id  :bigint           not null
#  knowledge_gap_id :bigint           not null
#  message_id       :bigint
#
# Indexes
#
#  idx_captain_knowledge_gap_occurrences_unique                (knowledge_gap_id,conversation_id) UNIQUE
#  index_captain_knowledge_gap_occurrences_on_account_id       (account_id)
#  index_captain_knowledge_gap_occurrences_on_conversation_id  (conversation_id)
#
class Captain::KnowledgeGapOccurrence < ApplicationRecord
  self.table_name = 'captain_knowledge_gap_occurrences'

  REASONS = %w[handoff no_source].freeze

  belongs_to :account
  belongs_to :knowledge_gap, class_name: 'Captain::KnowledgeGap', inverse_of: :occurrences
  belongs_to :conversation, class_name: '::Conversation'

  validates :reason, inclusion: { in: REASONS }
  validates :conversation_id, uniqueness: { scope: :knowledge_gap_id }

  before_validation :ensure_account

  private

  def ensure_account
    self.account = knowledge_gap&.account
  end
end

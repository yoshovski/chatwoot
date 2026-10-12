class Captain::ConversationMemory < ApplicationRecord
  self.table_name = 'captain_conversation_memories'

  belongs_to :account, class_name: '::Account'
  belongs_to :conversation, class_name: '::Conversation'
  belongs_to :assistant, class_name: 'Captain::Assistant'

  validate :same_account

  def self.invalidate_for_conversation!(conversation)
    where(account_id: conversation.account_id, conversation_id: conversation.id).find_each do |memory|
      memory.with_lock { memory.invalidate! }
    end
  end

  def invalidate!(boundary_message_id: 0)
    update!(summary: '', facts: [], covered_message_id: 0, boundary_message_id: boundary_message_id, source_digest: nil, revision: revision + 1)
  end

  private

  def same_account
    errors.add(:account, 'must match conversation and assistant') unless conversation.account_id == account_id && assistant.account_id == account_id
  end
end

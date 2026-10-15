class AddAiParticipatedAtToConversations < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  # Marks conversations an AI agent (Captain assistant or agent bot) took part in,
  # so the AI Agents view keeps them after a handoff to a human. The partial index
  # keeps that view cheap: it only covers conversations the AI touched.
  def up
    add_column :conversations, :ai_participated_at, :datetime, if_not_exists: true
    add_index :conversations, [:account_id, :status, :last_activity_at],
              name: 'index_conversations_on_ai_participated', where: 'ai_participated_at IS NOT NULL',
              algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :conversations, name: 'index_conversations_on_ai_participated', algorithm: :concurrently, if_exists: true
    remove_column :conversations, :ai_participated_at, if_exists: true
  end
end

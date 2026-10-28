# Customer questions the AI couldn't answer (a missing-knowledge handoff, or a knowledge search whose reply used no
# source), grouped per assistant by normalised question text. Occurrences keep one row per conversation.
class CreateCaptainKnowledgeGaps < ActiveRecord::Migration[7.1]
  def change # rubocop:disable Metrics/MethodLength
    create_table :captain_knowledge_gaps do |t|
      t.references :account, null: false, index: true
      t.references :assistant, null: false, index: false
      t.string :question, null: false, limit: 500
      t.string :normalized_question, null: false
      t.integer :status, null: false, default: 0
      t.integer :occurrences_count, null: false, default: 0
      t.datetime :last_seen_at, null: false
      t.bigint :response_id
      t.timestamps
    end
    add_index :captain_knowledge_gaps, [:assistant_id, :normalized_question], unique: true
    add_index :captain_knowledge_gaps, [:account_id, :assistant_id, :status, :last_seen_at], name: 'idx_captain_knowledge_gaps_listing'

    create_table :captain_knowledge_gap_occurrences do |t|
      t.references :account, null: false, index: true
      t.references :knowledge_gap, null: false, index: false
      t.references :conversation, null: false, index: true
      t.bigint :message_id
      t.string :reason, null: false
      t.timestamps
    end
    add_index :captain_knowledge_gap_occurrences, [:knowledge_gap_id, :conversation_id], unique: true,
                                                                                         name: 'idx_captain_knowledge_gap_occurrences_unique'
  end
end

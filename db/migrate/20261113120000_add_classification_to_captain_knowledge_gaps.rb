# T18: each gap is classified by the fast model (knowledge, action request, personal, off topic), rewritten into one
# general question with a topic, embedded for merging, and may carry a draft answer from a human reply.
# Occurrences keep the raw customer text, so the gap's question can be the rewritten one.
class AddClassificationToCaptainKnowledgeGaps < ActiveRecord::Migration[7.1]
  def change
    change_table :captain_knowledge_gaps, bulk: true do |t|
      t.integer :kind, null: false, default: 0
      t.string :intent, limit: 40
      t.string :topic, limit: 120
      t.string :language, limit: 10
      t.text :draft_answer
      t.datetime :classified_at
    end
    add_column :captain_knowledge_gaps, :embedding, :vector, limit: 1536
    add_index :captain_knowledge_gaps, [:assistant_id, :kind, :status], name: 'idx_captain_knowledge_gaps_kind'

    change_table :captain_knowledge_gap_occurrences, bulk: true do |t|
      t.string :question, limit: 500
      t.string :normalized_question
    end
    add_index :captain_knowledge_gap_occurrences, [:account_id, :normalized_question], name: 'idx_captain_knowledge_gap_occurrences_text'
  end
end

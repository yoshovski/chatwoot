class CreateCaptainConversationMemories < ActiveRecord::Migration[7.1]
  def change
    create_table :captain_conversation_memories do |t|
      t.references :account, type: :integer, null: false, foreign_key: { on_delete: :cascade }
      t.references :conversation, type: :integer, null: false, foreign_key: { on_delete: :cascade }
      t.references :assistant, null: false, foreign_key: { to_table: :captain_assistants, on_delete: :cascade }
      t.text :summary, default: '', null: false
      t.jsonb :facts, default: [], null: false
      t.bigint :covered_message_id, default: 0, null: false
      t.bigint :boundary_message_id, default: 0, null: false
      t.string :source_digest
      t.bigint :revision, default: 0, null: false
      t.string :model
      t.integer :prompt_version, default: 1, null: false
      t.timestamps
    end
    add_index :captain_conversation_memories, [:conversation_id, :assistant_id], unique: true, name: 'index_captain_memory_identity'
  end
end

# Actions the AI agent schedules for later in one conversation, such as a follow-up message or email. Generic, so later
# kinds can reuse it. A pending row is cancelled when the visitor writes, a human replies, or the conversation is
# resolved or handed off.
class CreateCaptainScheduledActions < ActiveRecord::Migration[7.1]
  def change # rubocop:disable Metrics/MethodLength
    create_table :captain_scheduled_actions do |t|
      t.references :account, null: false, index: true
      t.references :conversation, null: false, index: true, foreign_key: { on_delete: :cascade }
      t.references :assistant, null: false, index: true
      t.string :kind, null: false
      t.string :status, null: false, default: 'pending'
      t.datetime :due_at, null: false
      t.jsonb :payload, null: false, default: {}
      t.jsonb :cancel_on, null: false, default: %w[visitor_message human_message resolved handoff]
      t.string :dedupe_key
      t.integer :attempts, null: false, default: 0
      t.text :last_error
      t.datetime :executed_at
      t.datetime :cancelled_at
      t.string :cancel_reason
      t.timestamps
    end
    add_index :captain_scheduled_actions, [:status, :due_at]
    add_index :captain_scheduled_actions, [:conversation_id, :kind, :dedupe_key], unique: true, where: "status = 'pending'",
                                                                                  name: 'idx_captain_scheduled_actions_pending_dedupe'
  end
end

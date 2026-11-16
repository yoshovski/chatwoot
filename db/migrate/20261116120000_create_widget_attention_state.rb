class CreateWidgetAttentionState < ActiveRecord::Migration[7.1]
  def change
    create_sessions
    create_events
  end

  private

  def create_sessions
    create_table :widget_attention_sessions do |t|
      t.references :contact_inbox, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.datetime :started_at, null: false
      t.datetime :last_activity_at, null: false
      t.datetime :last_cue_at
      t.datetime :last_sound_at
      t.integer :question_count, null: false, default: 0
      t.boolean :checked_in, null: false, default: false
      t.boolean :snoozed, null: false, default: false
      t.timestamps
    end
  end

  def create_events
    create_table :widget_attention_events do |t|
      t.references :contact_inbox, null: false, foreign_key: { on_delete: :cascade }
      t.references :conversation, null: false, foreign_key: { on_delete: :cascade }
      t.references :message, null: false, foreign_key: { on_delete: :cascade }
      t.string :event_key, null: false
      t.string :kind, null: false
      t.string :status, null: false, default: 'claimed'
      t.timestamps
    end
    add_index :widget_attention_events, [:contact_inbox_id, :event_key], unique: true, name: 'index_widget_attention_events_on_claim'
    add_index :widget_attention_events, [:conversation_id, :kind]
  end
end

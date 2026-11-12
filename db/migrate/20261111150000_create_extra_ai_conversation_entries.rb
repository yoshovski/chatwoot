# One meter for ChatOctave (T03): the plan allowance, then extra AI conversations that were bought. Every change to the
# extra balance is one row here. A purchase row is a lot with its own expiry; usage and expiry rows take from a lot.
class CreateExtraAiConversationEntries < ActiveRecord::Migration[7.2]
  def change
    create_table :extra_ai_conversation_entries do |t|
      t.references :account, null: false, index: true
      t.string :reason, null: false
      t.integer :amount, null: false
      # Purchase rows only: how much of the lot is left, and when it expires.
      t.integer :remaining
      t.datetime :expires_at
      # Usage and expiry rows: the purchase lot they take from.
      t.references :lot, index: true
      t.references :conversation_usage_window, index: true
      t.string :stripe_reference
      t.references :user, index: true
      t.timestamps
    end
    add_index :extra_ai_conversation_entries, :stripe_reference, unique: true, where: 'stripe_reference IS NOT NULL'
    add_index :extra_ai_conversation_entries, [:account_id, :expires_at], where: 'remaining > 0', name: 'index_extra_ai_conversation_open_lots'

    add_column :conversation_usage_windows, :extra, :boolean, default: false, null: false
  end
end

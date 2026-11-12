# T10: a Super Admin adjustment says why it was granted.
class AddNoteToExtraAiConversationEntries < ActiveRecord::Migration[7.2]
  def change
    add_column :extra_ai_conversation_entries, :note, :string
  end
end

class AddEnabledToCaptainDocumentsAndResponses < ActiveRecord::Migration[7.0]
  def change
    add_column :captain_documents, :enabled, :boolean, default: true, null: false
    add_column :captain_assistant_responses, :enabled, :boolean, default: true, null: false

    add_index :captain_documents, :enabled
    add_index :captain_assistant_responses, :enabled
  end
end

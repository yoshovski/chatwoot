class AddDifyDocumentIdToCaptainAssistantResponses < ActiveRecord::Migration[7.1]
  def change
    add_column :captain_assistant_responses, :dify_document_id, :string
    add_index :captain_assistant_responses, :dify_document_id
  end
end

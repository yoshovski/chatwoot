class AddAgentsOnlyToCaptainKnowledge < ActiveRecord::Migration[7.1]
  def change
    add_column :captain_documents, :agents_only, :boolean, default: false, null: false
    add_column :captain_assistant_responses, :agents_only, :boolean, default: false, null: false
  end
end

class AddOriginToCaptainAssistantResponses < ActiveRecord::Migration[7.1]
  def change
    add_column :captain_assistant_responses, :origin, :string
  end
end

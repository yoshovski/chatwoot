class AddSourcesToAgentSessions < ActiveRecord::Migration[7.1]
  def change
    add_column :agent_sessions, :sources, :jsonb, default: [], null: false
  end
end

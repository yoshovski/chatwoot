# T17: the AI summary replaces lead and action notes for new agents. Agents that exist today keep posting them.
class KeepPrivateNotesForExistingCaptainAssistants < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL.squish
      UPDATE captain_assistants
      SET config = '{"lead_private_note": true, "action_private_note": true}'::jsonb || COALESCE(config, '{}'::jsonb)
    SQL
  end

  def down; end
end

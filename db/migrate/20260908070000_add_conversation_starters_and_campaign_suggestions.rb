class AddConversationStartersAndCampaignSuggestions < ActiveRecord::Migration[7.1]
  def up
    add_column :channel_web_widgets, :conversation_starters, :jsonb, default: [], null: false
    add_column :campaigns, :suggested_responses, :jsonb, default: [], null: false

    execute <<~SQL.squish
      UPDATE channel_web_widgets
      SET widget_style = 'standard'
      WHERE widget_style = 'flat'
    SQL
  end

  def down
    remove_column :campaigns, :suggested_responses
    remove_column :channel_web_widgets, :conversation_starters
  end
end

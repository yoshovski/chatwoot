class AddDemoModeToChannelWebWidgets < ActiveRecord::Migration[7.1]
  def change
    add_column :channel_web_widgets, :demo_mode_enabled, :boolean, default: false, null: false
  end
end

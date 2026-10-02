class AddAppearanceSettingsToChannelWebWidgets < ActiveRecord::Migration[7.1]
  def change
    add_column :channel_web_widgets, :widget_text_color, :string
    add_column :channel_web_widgets, :widget_icon_color, :string
    add_column :channel_web_widgets, :widget_height, :integer, default: 640, null: false
    add_column :channel_web_widgets, :widget_style, :string, default: 'standard', null: false
  end
end

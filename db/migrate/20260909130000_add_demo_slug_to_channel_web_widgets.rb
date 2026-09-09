class AddDemoSlugToChannelWebWidgets < ActiveRecord::Migration[7.1]
  def change
    add_column :channel_web_widgets, :demo_slug, :string
    add_index :channel_web_widgets, :demo_slug, unique: true
  end
end

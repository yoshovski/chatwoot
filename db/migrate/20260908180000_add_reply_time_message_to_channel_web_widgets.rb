class AddReplyTimeMessageToChannelWebWidgets < ActiveRecord::Migration[7.1]
  def change
    add_column :channel_web_widgets, :reply_time_message, :string
  end
end

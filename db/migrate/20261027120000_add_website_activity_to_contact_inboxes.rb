class AddWebsiteActivityToContactInboxes < ActiveRecord::Migration[7.1]
  def change
    add_column :contact_inboxes, :website_activity, :jsonb, null: false, default: {}
  end
end

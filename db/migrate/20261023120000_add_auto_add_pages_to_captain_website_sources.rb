class AddAutoAddPagesToCaptainWebsiteSources < ActiveRecord::Migration[7.1]
  def change
    add_column :captain_website_sources, :auto_add_pages, :boolean, default: true, null: false
  end
end

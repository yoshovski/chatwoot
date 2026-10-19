class CreateCaptainWebsiteSources < ActiveRecord::Migration[7.1]
  def change
    create_website_sources
    create_knowledge_briefs
  end

  private

  def create_website_sources
    create_table :captain_website_sources do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :assistant, null: false, foreign_key: { to_table: :captain_assistants, on_delete: :cascade }
      t.text :url, null: false
      t.boolean :include_subdomains, default: true, null: false
      t.string :status, default: 'pending', null: false
      t.jsonb :pages, default: [], null: false
      t.jsonb :selected_urls, default: [], null: false
      t.jsonb :discovery_stats, default: {}, null: false
      t.string :error_code
      t.datetime :discovered_at
      t.timestamps
    end
    add_index :captain_website_sources, 'assistant_id, md5(url)', unique: true, name: 'index_captain_website_sources_on_assistant_url'
  end

  def create_knowledge_briefs
    create_table :captain_knowledge_briefs do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :assistant, null: false, index: { unique: true },
                               foreign_key: { to_table: :captain_assistants, on_delete: :cascade }
      t.string :status, default: 'idle', null: false
      t.jsonb :draft, default: {}, null: false
      t.jsonb :published, default: {}, null: false
      t.string :error_code
      t.datetime :generated_at
      t.timestamps
    end
  end
end

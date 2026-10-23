class CreateCaptainMcpServers < ActiveRecord::Migration[7.1]
  def change
    create_table :captain_mcp_servers do |t|
      t.references :account, null: false, index: true
      t.string :name, null: false
      t.text :endpoint_url, null: false
      t.string :auth_type, null: false, default: 'none'
      t.string :auth_header_name
      t.text :auth_token
      t.jsonb :tools, null: false, default: []
      t.string :status, null: false, default: 'pending'
      t.text :last_error
      t.datetime :synced_at
      t.timestamps
    end
  end
end

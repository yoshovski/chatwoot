class CreateDifyWorkspaces < ActiveRecord::Migration[7.1]
  def change
    create_table :dify_workspaces do |t|
      t.boolean :enabled, null: false, default: false
      t.string :base_url
      t.text :knowledge_api_key
      t.string :embedding_model_provider
      t.string :embedding_model
      t.string :reranking_model_provider
      t.string :reranking_model
      t.timestamps
    end
    add_check_constraint :dify_workspaces, 'id = 1', name: 'dify_workspace_singleton'
  end
end

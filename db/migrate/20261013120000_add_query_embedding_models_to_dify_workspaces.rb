class AddQueryEmbeddingModelsToDifyWorkspaces < ActiveRecord::Migration[7.1]
  def change
    change_table :dify_workspaces, bulk: true do |t|
      t.string :query_embedding_model_provider
      t.string :query_embedding_model
    end
  end
end

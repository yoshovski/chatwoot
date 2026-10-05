class AddDifyKnowledgeToAccounts < ActiveRecord::Migration[7.1]
  def change
    add_column :accounts, :dify_base_url, :text
    add_column :accounts, :dify_knowledge_api_key, :text
    add_column :accounts, :dify_embedding_model, :text
    add_column :accounts, :dify_embedding_model_provider, :text
  end
end

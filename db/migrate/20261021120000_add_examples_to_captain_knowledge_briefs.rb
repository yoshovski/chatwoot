class AddExamplesToCaptainKnowledgeBriefs < ActiveRecord::Migration[7.1]
  def change
    add_column :captain_knowledge_briefs, :examples, :jsonb, default: {}, null: false
  end
end

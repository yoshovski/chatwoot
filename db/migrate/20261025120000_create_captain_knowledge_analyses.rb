class CreateCaptainKnowledgeAnalyses < ActiveRecord::Migration[7.1]
  def change
    create_analysis_runs
    create_document_analyses
  end

  private

  def create_analysis_runs
    create_table :captain_knowledge_analysis_runs do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :assistant, null: false, foreign_key: { to_table: :captain_assistants, on_delete: :cascade }
      t.string :corpus_fingerprint, null: false
      t.integer :analysis_version, default: 1, null: false
      t.string :llm_model
      t.string :status, default: 'pending', null: false
      t.bigint :cursor, default: 0, null: false
      add_run_token_columns(t)
      t.jsonb :stats, default: {}, null: false
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end
    add_index :captain_knowledge_analysis_runs, %i[assistant_id created_at], name: 'idx_captain_analysis_runs_on_assistant_created'
  end

  def add_run_token_columns(table)
    table.integer :token_budget
    table.integer :reserved_tokens, default: 0, null: false
    table.integer :input_tokens, default: 0, null: false
    table.integer :output_tokens, default: 0, null: false
    table.integer :cached_tokens, default: 0, null: false
    table.integer :calls_count, default: 0, null: false
    table.integer :retries_count, default: 0, null: false
  end

  def create_document_analyses
    create_table :captain_document_analyses do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :assistant, null: false, foreign_key: { to_table: :captain_assistants, on_delete: :cascade }
      t.references :document, null: false, foreign_key: { to_table: :captain_documents, on_delete: :cascade }
      t.string :content_fingerprint, null: false
      t.integer :analysis_version, default: 1, null: false
      t.string :status, default: 'pending', null: false
      t.string :reason
      t.jsonb :page_roles, default: [], null: false
      t.integer :overview_score, default: 0, null: false
      t.integer :support_score, default: 0, null: false
      t.integer :inspected_sections, default: 0, null: false
      t.integer :total_sections, default: 0, null: false
      t.jsonb :offerings, default: [], null: false
      t.jsonb :usage, default: {}, null: false
      t.timestamps
    end
    add_index :captain_document_analyses, %i[assistant_id document_id analysis_version],
              unique: true, name: 'idx_captain_doc_analyses_on_assistant_doc_version'
  end
end

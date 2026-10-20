# Whether any AI agent of this installation still uses a Dify dataset, as its own or as an extra dataset.
module Captain::Dify::DatasetReferences
  KEYS = %w[dify_faq_dataset_id dify_docs_dataset_id dify_faq_qa_dataset_id dify_legacy_faq_dataset_id].freeze

  CONDITION = KEYS.map { |key| "config->>'#{key}' = :id" }.push("config->'dify_extra_dataset_ids' ? :id").join(' OR ')

  def self.referenced?(dataset_id)
    Captain::Assistant.exists?([CONDITION, { id: dataset_id }])
  end
end

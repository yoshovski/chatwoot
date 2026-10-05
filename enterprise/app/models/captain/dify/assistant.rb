module Captain::Dify::Assistant
  extend ActiveSupport::Concern

  CONFIGURATION_KEYS = %w[dify_faq_dataset_id dify_docs_dataset_id dify_extra_dataset_ids
                          dify_faq_qa_dataset_id dify_legacy_faq_dataset_id].freeze

  prepended do
    after_create_commit :provision_dify_datasets, if: -> { account.dify_knowledge_enabled? }
    before_destroy :delete_dify_faq_documents
    before_destroy :delete_dify_documents
  end

  def client_config
    config.except(*CONFIGURATION_KEYS)
  end

  def ensure_dify_datasets!
    Captain::Dify::DatasetProvisioningService.new(self).perform
  end

  def dify_dataset_ids
    ensure_dify_datasets!
    config.values_at('dify_faq_dataset_id', 'dify_docs_dataset_id') + config.fetch('dify_extra_dataset_ids', [])
  end

  # Platform console only. The client API never permits these IDs.
  def dify_extra_dataset_ids=(dataset_ids)
    raise ArgumentError, 'Expected an array of dataset IDs' unless dataset_ids.is_a?(Array) && dataset_ids.all? do |id|
      id.is_a?(String) && id.present?
    end

    dataset_ids.each { |id| account.dify_knowledge_client.dataset(id) }
    self.config = config.merge('dify_extra_dataset_ids' => dataset_ids.uniq)
  end

  private

  def delete_dify_documents
    documents.where("metadata->>'dify_document_id' IS NOT NULL").find_each do |document|
      Captain::Dify::DeleteDocumentJob.perform_later(document.id, account_id, config.fetch('dify_docs_dataset_id'), document.dify_document_id)
    end
  end

  def delete_dify_faq_documents
    responses.where.not(dify_document_id: nil).find_each do |response|
      Captain::Dify::DeleteFaqJob.perform_later(response.id, account_id, config.fetch('dify_faq_dataset_id'), response.dify_document_id)
    end
  end

  def provision_dify_datasets
    Captain::Dify::ProvisionDatasetsJob.perform_later(id)
  end
end

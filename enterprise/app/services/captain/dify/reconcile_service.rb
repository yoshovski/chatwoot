# Re-uploads documents and FAQs whose Dify copy no longer exists, for example after a dataset was replaced.
# Without this they keep showing as synced while search can never find them.
class Captain::Dify::ReconcileService
  PAGE_SIZE = 100

  def initialize(assistant)
    @assistant = assistant
    @client = assistant.account.dify_knowledge_client
  end

  def perform
    @assistant.ensure_dify_datasets!
    config = @assistant.reload.config
    documents = missing(@assistant.documents.where("metadata->>'dify_document_id' IS NOT NULL"), config.fetch('dify_docs_dataset_id'))
    faqs = missing(@assistant.responses.where.not(dify_document_id: nil), config.fetch('dify_faq_dataset_id'))

    documents.each do |document|
      document.update!(dify_document_id: nil, dify_content_fingerprint: nil, dify_indexing_status: nil)
      Captain::Dify::SyncDocumentJob.perform_later(document.id)
    end
    # Clearing the ID makes the FAQ's commit callback enqueue its sync.
    faqs.each { |response| response.update!(dify_document_id: nil) }

    { documents: documents.size, faqs: faqs.size }
  end

  private

  def missing(records, dataset_id)
    existing = dataset_document_ids(dataset_id)
    records.reject { |record| existing.include?(record.dify_document_id) }
  end

  def dataset_document_ids(dataset_id)
    ids = Set.new
    page = 1
    loop do
      result = @client.documents(dataset_id: dataset_id, keyword: '', page: page, limit: PAGE_SIZE)
      ids.merge(result.fetch('data').map { |document| document.fetch('id') })
      break unless result['has_more']

      page += 1
    end
    ids
  end
end

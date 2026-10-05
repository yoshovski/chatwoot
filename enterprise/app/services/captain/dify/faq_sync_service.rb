class Captain::Dify::FaqSyncService
  class IndexingPending < Dify::KnowledgeClient::Error; end

  def initialize(response)
    @response = response
    @client = response.account.dify_knowledge_client
  end

  def perform
    # Commit the ID before polling: an indexing retry must not create another document.
    @response.with_lock do
      assistant = Captain::Assistant.find(@response.assistant_id)
      assistant.ensure_dify_datasets!
      @dataset_id = assistant.config.fetch('dify_faq_dataset_id')
      ensure_document
    end
    @response.with_lock do
      @dataset_id = Captain::Assistant.find(@response.assistant_id).config.fetch('dify_faq_dataset_id')
      raise IndexingPending, 'Dify FAQ moved during sync' if @response.dify_document_id.nil?

      sync_segment
    end
  end

  private

  def ensure_document
    return if @response.dify_document_id.present?

    name = "Captain FAQ #{@response.id}."
    documents = @client.documents(dataset_id: @dataset_id, keyword: name).fetch('data').select { |document| document.fetch('name') == name }
    raise Dify::KnowledgeClient::Error, 'Duplicate Dify FAQ documents' if documents.size > 1

    # Recover a successful POST whose response was lost before its ID was saved.
    document = documents.first || @client.create_by_text(
      dataset_id: @dataset_id, name: name, text: name, indexing_technique: 'high_quality', doc_form: 'text_model',
      process_rule: { mode: 'custom', rules: { pre_processing_rules: [], segmentation: { separator: "\n\n", max_tokens: 50 } } }
    ).fetch('document')
    @response.update!(dify_document_id: document.fetch('id'))
  end

  def sync_segment
    document_id = @response.dify_document_id
    document = @client.document(dataset_id: @dataset_id, document_id: document_id)
    raise Dify::KnowledgeClient::Error, 'Dify FAQ document indexing failed' if document.fetch('indexing_status') == 'error'
    raise IndexingPending, 'Dify FAQ document is indexing' unless document.fetch('indexing_status') == 'completed'

    chunks = @client.segments(dataset_id: @dataset_id, document_id: document_id)
    raise Dify::KnowledgeClient::Error, 'Expected exactly one Dify FAQ chunk' unless chunks.fetch('total') == 1

    segment = chunks.fetch('data').first
    content = "question: #{@response.question}\nanswer: #{@response.answer}"
    return if chunk_synced?(segment, content)

    segment = @client.update_segment(dataset_id: @dataset_id, document_id: document_id, segment_id: segment.fetch('id'),
                                     content: content, enabled: true).fetch('data')
    return if chunk_synced?(segment, content)

    raise Dify::KnowledgeClient::Error, 'Dify FAQ chunk indexing failed'
  end

  def chunk_synced?(segment, content)
    segment.values_at('content', 'enabled', 'status') == [content, true, 'completed']
  end
end

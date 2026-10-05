class Captain::Dify::FaqSyncService
  class IndexingPending < Dify::KnowledgeClient::Error; end

  def initialize(response, dataset_id: nil)
    @response = response
    @client = response.account.dify_knowledge_client
    @target_dataset_id = dataset_id
  end

  def perform
    # Commit the ID before polling: an indexing retry must not create another document.
    assistant = Captain::Assistant.find(@response.assistant_id)
    assistant.ensure_dify_datasets! unless @target_dataset_id
    @response.with_lock do
      @dataset_id = @target_dataset_id || assistant.reload.config.fetch('dify_faq_dataset_id')
      ensure_document
    end
    @response.with_lock do
      unless @target_dataset_id
        @dataset_id = Captain::Assistant.find(@response.assistant_id).config.fetch('dify_faq_dataset_id')
        @document_id = @response.dify_document_id
      end
      raise IndexingPending, 'Dify FAQ moved during sync' if @document_id.nil?

      sync_segment
    end
    @document_id
  end

  private

  def ensure_document
    @document_id = @response.dify_document_id unless @target_dataset_id
    return if @document_id.present?

    name = "Captain FAQ #{@response.id}."
    documents = @client.documents(dataset_id: @dataset_id, keyword: name).fetch('data').select { |document| document.fetch('name') == name }
    raise Dify::KnowledgeClient::Error, 'Duplicate Dify FAQ documents' if documents.size > 1

    # Recover a successful POST whose response was lost before its ID was saved.
    document = documents.first || @client.create_by_text(
      dataset_id: @dataset_id, name: name, text: 'Question: Is this a staging FAQ? Answer: Yes, replace it with the source FAQ.',
      indexing_technique: 'high_quality', doc_form: 'qa_model',
      process_rule: { mode: 'custom', rules: { pre_processing_rules: [], segmentation: { separator: "\n\n", max_tokens: 50 } } }
    ).fetch('document')
    @document_id = document.fetch('id')
    @response.update!(dify_document_id: @document_id) unless @target_dataset_id
  end

  def sync_segment
    document_id = @document_id
    document = @client.document(dataset_id: @dataset_id, document_id: document_id)
    unless document.fetch('doc_form') == 'qa_model'
      raise Dify::KnowledgeClient::Error, 'Convert the FAQ dataset to native Q&A with captain:dify:migrate_faqs'
    end
    raise Dify::KnowledgeClient::Error, 'Dify FAQ document indexing failed' if document.fetch('indexing_status') == 'error'
    raise IndexingPending, 'Dify FAQ document is indexing' unless document.fetch('indexing_status') == 'completed'

    segment = source_segment
    return if segment && chunk_synced?(segment)

    segment = write_segment(segment)
    return if chunk_synced?(segment)

    raise Dify::KnowledgeClient::Error, 'Dify FAQ chunk indexing failed'
  end

  def source_segment
    chunks = @client.segments(dataset_id: @dataset_id, document_id: @document_id)
    # The staging text can generate zero or several Q&A pairs. Replace those with one exact source pair.
    while chunks.fetch('total') > 1
      chunks.fetch('data').each do |segment|
        @client.delete_segment(dataset_id: @dataset_id, document_id: @document_id, segment_id: segment.fetch('id'))
      end
      chunks = @client.segments(dataset_id: @dataset_id, document_id: @document_id)
    end
    chunks.fetch('data').first
  end

  def write_segment(segment)
    attributes = { content: @response.question, answer: @response.answer }
    if segment
      @client.update_segment(dataset_id: @dataset_id, document_id: @document_id, segment_id: segment.fetch('id'),
                             **attributes, enabled: true).fetch('data')
    else
      @client.create_segments(dataset_id: @dataset_id, document_id: @document_id, segments: [attributes]).fetch('data').first
    end
  end

  def chunk_synced?(segment)
    segment.values_at('content', 'answer', 'enabled', 'status') == [@response.question, @response.answer, true, 'completed']
  end
end

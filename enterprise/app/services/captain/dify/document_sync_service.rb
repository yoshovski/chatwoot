class Captain::Dify::DocumentSyncService
  class IndexingPending < Dify::KnowledgeClient::Error; end

  PROCESS_RULE = {
    mode: 'hierarchical', rules: {
      pre_processing_rules: [], parent_mode: 'paragraph', segmentation: { separator: "\n\n", max_tokens: 1024 },
      subchunk_segmentation: { separator: "\n", max_tokens: 256 }
    }
  }.freeze

  def initialize(document)
    @document = document
    @client = document.account.dify_knowledge_client
  end

  def perform
    @document.with_lock do
      assistant = Captain::Assistant.find(@document.assistant_id)
      assistant.ensure_dify_datasets!
      @dataset_id = assistant.config.fetch('dify_docs_dataset_id')
      ensure_document
    end
    @document.with_lock { sync_content }
  end

  private

  def ensure_document
    return if @document.dify_document_id.present?

    name = "Captain Document #{@document.id}."
    documents = @client.documents(dataset_id: @dataset_id, keyword: name).fetch('data').select { |document| document.fetch('name') == name }
    raise Dify::KnowledgeClient::Error, 'Duplicate Dify documents' if documents.size > 1

    if documents.any?
      @document.update!(dify_document_id: documents.first.fetch('id'))
    else
      persist_write(write_document(name: name))
    end
  end

  def sync_content
    fingerprint = @document.dify_source_fingerprint
    if fingerprint == @document.dify_content_fingerprint
      return if @document.available? && @document.dify_indexing_status == 'completed'
      return [@document.dify_document_id, fingerprint] unless @document.dify_indexing_status == 'error'
    end

    state = @client.document(dataset_id: @dataset_id, document_id: @document.dify_document_id).fetch('indexing_status')
    raise IndexingPending, 'Dify document is indexing' unless %w[completed error].include?(state)

    persist_write(write_document(name: "Captain Document #{@document.id}.", document_id: @document.dify_document_id))
    [@document.dify_document_id, fingerprint]
  end

  def write_document(name:, document_id: nil)
    attributes = { name: name, indexing_technique: 'high_quality', doc_form: 'hierarchical_model', process_rule: PROCESS_RULE }
    if @document.pdf_document?
      attributes[:original_document_id] = document_id if document_id
      @document.pdf_file.blob.open do |file|
        @client.create_by_file(dataset_id: @dataset_id, file: file, filename: @document.pdf_file.filename.to_s,
                               content_type: 'application/pdf', **attributes)
      end
    elsif document_id
      @client.update_by_text(dataset_id: @dataset_id, document_id: document_id, text: @document.dify_sectioned_content, **attributes)
    else
      @client.create_by_text(dataset_id: @dataset_id, text: @document.dify_sectioned_content, **attributes)
    end
  end

  def persist_write(result)
    document = result.fetch('document')
    if @document.dify_document_id.present? && @document.dify_document_id != document.fetch('id')
      raise Dify::KnowledgeClient::Error, 'Dify changed the document ID during update'
    end

    @document.update!(dify_document_id: document.fetch('id'), dify_content_fingerprint: @document.dify_source_fingerprint,
                      dify_indexing_status: document.fetch('indexing_status'), status: :in_progress, sync_status: :syncing,
                      sync_step: nil, last_sync_error_code: nil, last_sync_attempted_at: Time.current)
  end
end

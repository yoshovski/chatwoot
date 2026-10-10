class Captain::Dify::FaqDatasetMigrationService
  def initialize(assistant)
    @assistant = assistant
    @client = assistant.account.dify_knowledge_client
  end

  def perform
    @assistant.ensure_dify_datasets!
    @source_id = @assistant.reload.config.fetch('dify_faq_dataset_id')
    @source = @client.dataset(@source_id)
    return if @source.fetch('doc_form').in?([nil, 'qa_model'])

    prepare_target
    staged = @assistant.responses.order(:id).map do |response|
      document_id = Captain::Dify::FaqSyncService.new(response, dataset_id: @target_id).perform
      [response.id, response.updated_at, response.dify_document_id, document_id]
    end
    purge_orphan_documents(staged)
    activate_target(staged)
  end

  private

  def purge_orphan_documents(staged)
    documents = []
    page = 1
    loop do
      result = @client.documents(dataset_id: @target_id, keyword: 'Captain FAQ ', page: page, limit: 100)
      documents.concat(result.fetch('data'))
      break unless result.fetch('has_more')

      page += 1
    end
    document_ids = staged.map(&:last)
    documents.reject { |document| document_ids.include?(document.fetch('id')) }.each do |document|
      @client.delete_document(dataset_id: @target_id, document_id: document.fetch('id'))
    end
  end

  def activate_target(staged)
    @assistant.with_lock do
      responses = @assistant.responses.order(:id).lock.to_a
      unless @assistant.config.fetch('dify_faq_dataset_id') == @source_id &&
             responses.map { |response| [response.id, response.updated_at, response.dify_document_id] } == staged.map { |row| row.first(3) }
        raise Captain::Dify::FaqSyncService::IndexingPending, 'FAQs changed during conversion; retry the migration'
      end

      responses.zip(staged).each { |response, row| response.update!(dify_document_id: row.last) }
      # Keep the original dataset as a rollback copy; only the Q&A dataset remains active.
      @assistant.update!(config: @assistant.config.except('dify_faq_qa_dataset_id').merge(
        'dify_faq_dataset_id' => @target_id, 'dify_legacy_faq_dataset_id' => @source_id
      ))
    end
  end

  def prepare_target
    @assistant.with_lock do
      @target_id = @assistant.config['dify_faq_qa_dataset_id']
      return if @target_id.present?

      dataset = @client.create_dataset(
        **Captain::Dify::DatasetIdentity.new(@assistant).attributes('faq'),
        indexing_technique: 'high_quality',
        permission: 'only_me',
        embedding_model: @source.fetch('embedding_model'),
        embedding_model_provider: @source.fetch('embedding_model_provider'),
        retrieval_model: @source.fetch('retrieval_model_dict')
      )
      @target_id = dataset.fetch('id')
      @assistant.update!(config: @assistant.config.merge('dify_faq_qa_dataset_id' => @target_id))
    end
  end
end

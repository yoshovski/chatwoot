class Captain::Dify::DatasetProvisioningService
  def initialize(assistant)
    @assistant = assistant
    @client = assistant.account.dify_knowledge_client
  end

  def perform
    identity = Captain::Dify::DatasetIdentity.new(@assistant)
    created = Captain::Dify::DatasetIdentity::KINDS.filter_map do |kind|
      @assistant.with_lock do
        key = "dify_#{kind}_dataset_id"
        next if @assistant.config[key].present?

        dataset = @client.create_dataset(
          **identity.attributes(kind),
          indexing_technique: 'high_quality',
          permission: 'only_me',
          embedding_model: @assistant.account.dify_embedding_model,
          embedding_model_provider: @assistant.account.dify_embedding_model_provider
        )
        @assistant.update!(config: @assistant.config.merge(key => dataset.fetch('id')))
      end
    end
    # Records synced into a replaced dataset would otherwise stay unsearchable.
    Captain::Dify::ReconcileJob.perform_later(@assistant.id) if created.any? && existing_records?
  end

  private

  def existing_records?
    @assistant.documents.exists?("metadata->>'dify_document_id' IS NOT NULL") || @assistant.responses.where.not(dify_document_id: nil).exists?
  end
end

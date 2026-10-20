class Captain::Dify::DatasetProvisioningService
  def initialize(assistant)
    @assistant = assistant
    @client = assistant.account.dify_knowledge_client
  end

  def perform
    return if Captain::Dify::DatasetIdentity::KINDS.all? { |kind| @assistant.config["dify_#{kind}_dataset_id"].present? }

    @assistant.with_lock do
      if @assistant.config['dify_provisioning_key'].blank?
        @assistant.update!(config: @assistant.config.merge('dify_provisioning_key' => SecureRandom.uuid))
      end
    end
    identity = Captain::Dify::DatasetIdentity.new(@assistant)
    created = Captain::Dify::DatasetIdentity::KINDS.filter_map do |kind|
      provision_dataset(identity, kind)
    end
    # Records synced into a replaced dataset would otherwise stay unsearchable.
    Captain::Dify::ReconcileJob.perform_later(@assistant.id) if created.any? && existing_records?
  end

  private

  def provision_dataset(identity, kind)
    @assistant.with_lock do
      key = "dify_#{kind}_dataset_id"
      return if @assistant.config[key].present?

      attributes = dataset_attributes(identity, kind)
      dataset = recover_dataset(identity.provisioning_marker(kind)) || create_dataset(attributes)
      @assistant.update!(config: @assistant.config.merge(key => dataset.fetch('id')))
    end
  end

  def recover_dataset(marker)
    matches = all_datasets.select { |dataset| dataset['description'].to_s.lines.map(&:strip).include?(marker) }
    raise Dify::KnowledgeClient::Error, 'Duplicate managed Dify datasets' if matches.size > 1

    matches.first
  end

  # Dify rejects a second dataset with the same name (HTTP 409). An agent recreated with the name of a
  # deleted one gets the deleted agent's dataset name; that dataset is taken over when nothing uses it.
  def create_dataset(attributes)
    @client.create_dataset(**attributes)
  rescue Dify::KnowledgeClient::Error => e
    raise unless e.status == 409

    orphan = orphaned_dataset(attributes[:name])
    raise unless orphan

    @client.update_dataset(orphan.fetch('id'), name: attributes[:name], description: attributes[:description])
    orphan
  end

  def orphaned_dataset(name)
    matches = all_datasets.select { |dataset| dataset['name'] == name }
    dataset = matches.first if matches.one?
    return unless dataset && dataset['embedding_model'] == @assistant.account.dify_embedding_model

    dataset unless Captain::Dify::DatasetReferences.referenced?(dataset.fetch('id'))
  end

  def all_datasets
    page = 1
    datasets = []
    loop do
      result = @client.datasets(page: page)
      datasets.concat(result.fetch('data'))
      break unless result['has_more']

      page += 1
    end
    datasets
  end

  def dataset_attributes(identity, kind)
    attributes = identity.attributes(kind).merge(
      indexing_technique: 'high_quality',
      permission: 'only_me',
      embedding_model: @assistant.account.dify_embedding_model,
      embedding_model_provider: @assistant.account.dify_embedding_model_provider
    )
    if @assistant.account.dify_query_embedding_model.present? && @assistant.account.dify_query_embedding_model_provider.present?
      attributes[:query_embedding_model] = @assistant.account.dify_query_embedding_model
      attributes[:query_embedding_model_provider] = @assistant.account.dify_query_embedding_model_provider
    end
    attributes
  end

  def existing_records?
    @assistant.documents.exists?("metadata->>'dify_document_id' IS NOT NULL") || @assistant.responses.where.not(dify_document_id: nil).exists?
  end
end

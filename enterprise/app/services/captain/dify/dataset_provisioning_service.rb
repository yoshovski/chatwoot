class Captain::Dify::DatasetProvisioningService
  DATASETS = { 'faq' => 'FAQs', 'docs' => 'Documents' }.freeze

  def initialize(assistant)
    @assistant = assistant
    @client = assistant.account.dify_knowledge_client
  end

  def perform
    DATASETS.each do |kind, label|
      @assistant.with_lock do
        key = "dify_#{kind}_dataset_id"
        next if @assistant.config[key].present?

        dataset = @client.create_dataset(
          name: "Captain #{@assistant.id} #{label}", indexing_technique: 'high_quality', permission: 'only_me',
          embedding_model: @assistant.account.dify_embedding_model,
          embedding_model_provider: @assistant.account.dify_embedding_model_provider
        )
        @assistant.update!(config: @assistant.config.merge(key => dataset.fetch('id')))
      end
    end
  end
end

class DifyWorkspace < ApplicationRecord
  CONFIGURATION_FIELDS = %w[base_url embedding_model_provider embedding_model reranking_model_provider reranking_model].freeze

  encrypts :knowledge_api_key
  validates :id, inclusion: { in: [1] }
  validates(*CONFIGURATION_FIELDS, :knowledge_api_key, presence: true, if: :enabled?)
  validate :validate_base_url, if: :enabled?

  def self.current
    find_by(id: 1)
  end

  def shopify_configured?
    ENV.fetch('SAT_ADMIN_KEY', nil).present? || ShopifyAgentTools::AdminClient.global_config('SAT_ADMIN_KEY').present?
  end

  def connection
    {
      url: "#{base_url.to_s.chomp('/')}/v1", api_key: knowledge_api_key,
      embedding_provider: embedding_model_provider, embedding_model: embedding_model,
      reranking_provider: reranking_model_provider, reranking_model: reranking_model
    }
  end

  private

  def validate_base_url
    uri = URI.parse(base_url.to_s)
    return if %w[http https].include?(uri.scheme) && uri.host.present? && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?

    errors.add(:base_url, :invalid)
  rescue URI::InvalidURIError
    errors.add(:base_url, :invalid)
  end
end

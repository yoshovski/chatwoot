module AccountDifyKnowledge
  extend ActiveSupport::Concern

  CONFIGURATION_FIELDS = %w[base_url embedding_model embedding_model_provider].freeze

  included do
    encrypts :dify_knowledge_api_key
    validate :validate_dify_configuration
    validate :validate_dify_url, if: :dify_knowledge_enabled?
  end

  def dify_configuration
    CONFIGURATION_FIELDS.index_with { |field| public_send("dify_#{field}") }
  end

  def dify_configuration=(configuration)
    CONFIGURATION_FIELDS.each { |field| public_send("dify_#{field}=", configuration.fetch(field)) }
    self.dify_knowledge_api_key = configuration['knowledge_api_key'] if configuration['knowledge_api_key'].present?
  end

  def dify_knowledge_enabled?
    dify_base_url.present? && dify_knowledge_api_key.present?
  end

  def dify_knowledge_client
    Dify::KnowledgeClient.new(base_url: dify_base_url, api_key: dify_knowledge_api_key)
  end

  private

  def validate_dify_configuration
    return if dify_base_url.blank? && dify_knowledge_api_key.blank?

    CONFIGURATION_FIELDS.each do |field|
      errors.add("dify_#{field}", :blank) if public_send("dify_#{field}").blank?
    end
    errors.add(:dify_knowledge_api_key, :blank) if dify_knowledge_api_key.blank?
  end

  def validate_dify_url
    uri = URI.parse(dify_base_url.to_s)
    return if %w[http https].include?(uri.scheme) && uri.host.present? && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?

    errors.add(:dify_base_url, :invalid)
  rescue URI::InvalidURIError
    errors.add(:dify_base_url, :invalid)
  end
end

# Request-local attribution: never change global RubyLLM configuration for a tenant.
module Llm::TenantTracking
  def self.headers(account_id:, feature:)
    return {} if account_id.blank?

    customer = "#{ENV.fetch('LITELLM_TENANT_ID_PREFIX', 'chatoctave')}-account-#{account_id}"
    { 'x-litellm-customer-id' => customer, 'x-litellm-tags' => "#{customer},feature:#{feature}" }
  end
end

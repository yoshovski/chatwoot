# AI cost per account from LiteLLM, for the Super Admin billing overview (T10). Every Captain request names the LiteLLM
# customer "<LITELLM_TENANT_ID_PREFIX>-account-<id>" (Llm::TenantTracking), and LiteLLM's /global/spend/end_users sums
# the spend per customer for a time range, in USD. It returns the top 100 customers of the range.
# Needs LITELLM_SPEND_URL (the proxy, e.g. http://shared-ai-litellm:4000) and LITELLM_SPEND_API_KEY (a key of a
# proxy_admin_viewer user: it may read spend but change nothing).
class Enterprise::Billing::AiSpendService
  class Unavailable < StandardError; end

  TIMEOUT = 20

  def self.configured?
    ENV['LITELLM_SPEND_URL'].present? && ENV['LITELLM_SPEND_API_KEY'].present?
  end

  # { account_id => cost in US cents } for requests that started in [from, to).
  def spend_cents(from:, to:)
    response = HTTParty.post("#{ENV.fetch('LITELLM_SPEND_URL').chomp('/')}/global/spend/end_users",
                             headers: { 'Authorization' => "Bearer #{ENV.fetch('LITELLM_SPEND_API_KEY')}", 'Content-Type' => 'application/json' },
                             body: { startTime: from.utc.iso8601, endTime: to.utc.iso8601 }.to_json, timeout: TIMEOUT)
    # The status only: the body could echo the request.
    raise Unavailable, "LiteLLM answered HTTP #{response.code}" unless response.success?

    by_account(response.parsed_response)
  rescue HTTParty::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, JSON::ParserError => e
    raise Unavailable, e.class.name
  end

  private

  def by_account(rows)
    prefix = "#{ENV.fetch('LITELLM_TENANT_ID_PREFIX', 'chatoctave')}-account-"
    Array(rows).each_with_object({}) do |row, costs|
      customer = row['end_user'].to_s
      next unless customer.start_with?(prefix)

      account_id = Integer(customer.delete_prefix(prefix), exception: false)
      costs[account_id] = (row['total_spend'].to_f * 100).round(2) if account_id
    end
  end
end

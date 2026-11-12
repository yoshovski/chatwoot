# AI cost per account from LiteLLM, for the Super Admin billing overview (T10). Every Captain request names the LiteLLM
# customer "<LITELLM_TENANT_ID_PREFIX>-account-<id>" (Llm::TenantTracking), and LiteLLM's /customer/daily/activity sums
# the spend of the customers asked for, per day, in USD.
# Needs LITELLM_SPEND_URL (the proxy, e.g. http://shared-ai-litellm:4000) and LITELLM_SPEND_API_KEY (a key of a
# proxy_admin_viewer user: it may read spend but change nothing).
class Enterprise::Billing::AiSpendService
  class Unavailable < StandardError; end

  TIMEOUT = 20
  IDS_PER_REQUEST = 50
  DAYS_PER_PAGE = 100

  def self.configured?
    ENV['LITELLM_SPEND_URL'].present? && ENV['LITELLM_SPEND_API_KEY'].present?
  end

  # { account_id => cost in US cents } for the given accounts, from the day `from` falls on (UTC) through today.
  def spend_cents(account_ids:, from:)
    account_ids.each_slice(IDS_PER_REQUEST).with_object({}) do |ids, costs|
      customers = ids.index_by { |id| "#{prefix}#{id}" }
      each_day(customers.keys, from.utc.to_date) do |day|
        day.dig('breakdown', 'entities')&.each do |customer, entity|
          account_id = customers[customer]
          costs[account_id] = (costs.fetch(account_id, 0) + (entity.dig('metrics', 'spend').to_f * 100)).round(4) if account_id
        end
      end
    end
  rescue HTTParty::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, JSON::ParserError => e
    raise Unavailable, e.class.name
  end

  private

  def prefix
    "#{ENV.fetch('LITELLM_TENANT_ID_PREFIX', 'chatoctave')}-account-"
  end

  def each_day(customers, start_date, &)
    page = 1
    loop do
      body = fetch(customers, start_date, page)
      body.fetch('results').each(&)
      break unless body.dig('metadata', 'has_more')

      page += 1
    end
  end

  def fetch(customers, start_date, page)
    response = HTTParty.get("#{ENV.fetch('LITELLM_SPEND_URL').chomp('/')}/customer/daily/activity",
                            headers: { 'Authorization' => "Bearer #{ENV.fetch('LITELLM_SPEND_API_KEY')}" },
                            query: { end_user_ids: customers.join(','), start_date: start_date.iso8601,
                                     end_date: Time.current.utc.to_date.iso8601, page: page, page_size: DAYS_PER_PAGE },
                            timeout: TIMEOUT)
    # The status only: an error body can echo part of the key.
    raise Unavailable, "LiteLLM answered HTTP #{response.code}" unless response.success?

    response.parsed_response
  end
end

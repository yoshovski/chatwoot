# A visitor's website address → a preview of their AI agent, without an account (T27). Reuses the instant agent (T13),
# which reads the homepage and up to five pages through SafeFetch within 15 seconds. The result of a website is
# reused for 24 hours, so the same address costs one read a day however often it is entered.
# Returns { status: :ready, token:, preview: } or { status: :invalid_url | :limited | :busy | :blocked }.
class Captain::AgentPreviews::CreateService
  def initialize(url:, ip:)
    @url = normalize(url)
    @ip = ip
  end

  def perform
    return { status: :invalid_url } if @url.nil?
    return { status: :limited } unless Captain::AgentPreviews::Limits.preview_allowed_for_ip?(@ip)

    result = Captain::AgentPreviews::Store.cached_result(domain) || read_website
    return { status: result } if result.is_a?(Symbol)
    return { status: :blocked } unless result[:status].to_s == 'ready'

    token = Captain::AgentPreviews::Store.create(url: @url, domain: domain, result: result)
    { status: :ready, token: token, preview: Captain::AgentPreviews::Store.find(token) }
  end

  private

  def read_website
    return :busy unless Captain::AgentPreviews::Limits.read_allowed?

    result = Captain::AgentPreviews::Limits.reading { Captain::Onboarding::InstantAgentService.new(@url).perform }
    return :busy if result == :busy

    # A site that blocks reading is cached too, so retries don't fetch it again.
    Captain::AgentPreviews::Store.cache_result(domain, result)
    result
  end

  def normalize(value)
    value = value.to_s.strip
    value = "https://#{value}" unless value.match?(%r{\Ahttps?://}i)
    url = Captain::Websites::UrlPolicy.normalize(value)
    url if url && PublicSuffix.valid?(URI.parse(url).host, default_rule: nil)
  rescue URI::InvalidURIError
    nil
  end

  def domain = @domain ||= URI.parse(@url).host.delete_prefix('www.')
end

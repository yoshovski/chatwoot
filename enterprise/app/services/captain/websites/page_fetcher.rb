class Captain::Websites::PageFetcher
  def initialize(source)
    @source = source
  end

  def fetch(url)
    origin = URI.join(url, '/').to_s.delete_suffix('/')
    policy = Rails.cache.fetch("captain_website_robots/#{Digest::SHA256.hexdigest(origin)}", expires_in: 10.minutes) do
      text = SafeFetch.fetch("#{origin}/robots.txt", validate_content_type: false, max_bytes: 512.kilobytes,
                                                     headers: { 'User-Agent' => "#{Captain::Websites::RobotsPolicy::AGENT}/1.0" }) do |result|
        result.tempfile.read
      end
      Captain::Websites::RobotsPolicy.new(text)
    rescue SafeFetch::HttpError => e
      Captain::Websites::RobotsPolicy.new('', denied: e.message.to_i != 404)
    end
    return failure('robots_disallowed') unless policy.allowed?(url)

    Captain::Documents::SinglePageFetcher.new(url).fetch
  rescue SafeFetch::Error
    failure('fetch_failed')
  end

  private

  def failure(code)
    Captain::Documents::SinglePageFetcher::Result.new(success: false, error_code: code)
  end
end

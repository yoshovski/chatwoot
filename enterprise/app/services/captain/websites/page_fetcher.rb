class Captain::Websites::PageFetcher
  def initialize(source)
    @source = source
  end

  def fetch(url)
    origin = URI.join(url, '/').to_s.delete_suffix('/')
    policy = robots_policy(origin)
    return failure('robots_disallowed') unless policy.allowed?(url)

    page = @source.pages.find { |item| item['url'] == url } || {}
    listed_copy(origin, page, policy) || Captain::Documents::SinglePageFetcher.new(url).fetch
  rescue SafeFetch::Error
    failure('fetch_failed')
  end

  private

  def robots_policy(origin)
    Rails.cache.fetch("captain_website_robots/#{Digest::SHA256.hexdigest(origin)}", expires_in: 10.minutes) do
      text = SafeFetch.fetch("#{origin}/robots.txt", validate_content_type: false, max_bytes: 512.kilobytes,
                                                     headers: { 'User-Agent' => "#{Captain::Websites::RobotsPolicy::AGENT}/1.0" }) do |result|
        result.tempfile.read
      end
      Captain::Websites::RobotsPolicy.new(text)
    rescue SafeFetch::HttpError => e
      Captain::Websites::RobotsPolicy.new('', denied: e.message.to_i != 404)
    end
  end

  # Help-centre articles are read from their API and documentation pages from their llms.txt markdown copy.
  def listed_copy(origin, page, policy)
    return help_center_article(origin, page['help_center_article_id'], policy) if page['help_center_article_id']

    markdown_page(page['markdown_url'], policy) if page['markdown_url']
  end

  # Help centres can restrict their API; the article page itself is the fallback.
  def help_center_article(origin, article_id, policy)
    return unless policy.allowed?("#{origin}/api/v2/help_center/articles/#{article_id}.json")

    article = Captain::Websites::HelpCenter.article(origin, article_id)
    return if article[:content].blank?

    Captain::Documents::SinglePageFetcher::Result.new(success: true, title: article[:title].to_s.first(255), content: article[:content],
                                                      faqs: article[:faqs])
  rescue SafeFetch::Error, JSON::ParserError, KeyError
    nil
  end

  # The markdown copy listed in llms.txt; the page itself is the fallback.
  def markdown_page(markdown_url, policy)
    Captain::Websites::LlmsIndex.page(markdown_url) if policy.allowed?(markdown_url)
  rescue SafeFetch::Error
    nil
  end

  def failure(code)
    Captain::Documents::SinglePageFetcher::Result.new(success: false, error_code: code)
  end
end

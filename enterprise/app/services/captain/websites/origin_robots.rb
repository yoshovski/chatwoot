# robots.txt for each origin discovery touches, read once. Each new origin's advertised and
# conventional sitemaps are passed to the block.
class Captain::Websites::OriginRobots
  MAX_ORIGINS = 40

  def initialize(fetcher, &on_sitemap)
    @fetcher = fetcher
    @on_sitemap = on_sitemap
    @policies = {}
    @limited = false
  end

  def limited? = @limited

  # nil past the origin limit: robots.txt is then unknown, not a refusal.
  def for(url)
    origin = URI.join(url, '/').to_s.delete_suffix('/')
    return @policies[origin] if @policies.key?(origin)

    if @policies.size >= MAX_ORIGINS
      @limited = true
      return
    end

    # Register before fetching so sitemaps referring to this origin cannot recurse.
    @policies[origin] = nil
    @policies[origin] = read(origin)
  end

  # Only origins already read are checked; the import checks robots.txt again before fetching.
  def disallowed?(url)
    policy = @policies[URI.join(url, '/').to_s.delete_suffix('/')]
    policy.present? && !policy.allowed?(url)
  end

  private

  def read(origin)
    status, text = @fetcher.read("#{origin}/robots.txt")
    denied = status.nil? || status.in?([401, 403, 429]) || status >= 500
    policy = Captain::Websites::RobotsPolicy.new(text.to_s, denied: denied)
    policy.sitemaps.each(&@on_sitemap)
    @on_sitemap.call("#{origin}/sitemap.xml")
    @on_sitemap.call("#{origin}/sitemap_index.xml") if policy.sitemaps.empty?
    policy
  end
end

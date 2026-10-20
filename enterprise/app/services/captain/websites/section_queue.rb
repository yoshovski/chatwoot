# Pages wait per section and are taken round-robin, so every section gets sampled before
# one large blog or docs tree uses the whole request budget.
class Captain::Websites::SectionQueue
  def initialize
    @urls = Hash.new { |urls, section| urls[section] = [] }
    @taken = Hash.new(0)
  end

  def push(url)
    @urls[Captain::Websites::PageRules.section(url)] << url
  end

  # The next URL, from the least-sampled section, that the block accepts.
  def shift
    while (section = @urls.select { |_, urls| urls.any? }.min_by { |key, _| @taken[key] }&.first)
      url = @urls[section].shift
      next unless yield url

      @taken[section] += 1
      return url
    end
  end

  def any?(&) = @urls.values.flatten.any?(&)
end

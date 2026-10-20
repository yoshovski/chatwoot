# The crawler uses the most specific matching user-agent group and longest path rule.
class Captain::Websites::RobotsPolicy
  AGENT = 'ChatOctaveKnowledgeBot'.freeze
  attr_reader :sitemaps, :delay

  def initialize(text, denied: false)
    @denied = denied
    @sitemaps = []
    @groups = []
    parse(text)
    best_match = @groups.map { |group| specificity(group) }.max
    applicable = @groups.select { |group| specificity(group) == best_match && best_match >= 0 }
    @rules = applicable.flat_map { |group| group[:rules] }
    @delay = applicable.filter_map { |group| group[:delay] }.max || 0.25
  end

  def allowed?(url)
    return false if @denied

    path = URI.parse(url).request_uri
    matches = @rules.select { |rule| rule[:pattern].match?(path) }
    winner = matches.max_by { |rule| [rule[:length], rule[:allow] ? 1 : 0] }
    winner.nil? || winner[:allow]
  end

  private

  def specificity(group)
    group[:agents].filter_map { |agent| agent == '*' ? 0 : (agent.length if AGENT.downcase.include?(agent)) }.max || -1
  end

  def parse(text)
    text.each_line { |line| parse_line(line) }
  end

  def parse_line(line)
    key, value = line.split('#', 2).first.to_s.strip.split(':', 2).map(&:strip)
    return if value.nil?

    case key.downcase
    when 'sitemap' then add_sitemap(value)
    when 'user-agent' then add_agent(value)
    when 'allow', 'disallow' then add_rule(key.downcase, value)
    when 'crawl-delay' then add_delay(value)
    end
  end

  def add_sitemap(value)
    @sitemaps << value if value.present?
  end

  def add_agent(value)
    if @group.nil? || @group[:has_directives]
      @group = { agents: [], rules: [], has_directives: false }
      @groups << @group
    end
    @group[:agents] << value.downcase if value.present?
  end

  def add_rule(key, value)
    return unless @group

    @group[:has_directives] = true
    return if value.blank?

    ending = value.end_with?('$') ? '\\z' : ''
    pattern = Regexp.escape(value.delete_suffix('$')).gsub('\\*', '.*')
    @group[:rules] << { pattern: Regexp.new("\\A#{pattern}#{ending}"), length: value.delete('*$').length, allow: key == 'allow' }
  end

  def add_delay(value)
    return unless @group

    @group[:has_directives] = true
    @group[:delay] = Float(value, exception: false)&.clamp(0.25, 60)
  end
end

class Captain::Assistant::ResponseParts
  MESSAGE_ATTRIBUTE_KEY = 'captain_v2_response_parts'.freeze
  MAX_SOURCE_LINKS = 3
  FALLBACK_MIN_SHARED_WORDS = 2
  FALLBACK_MIN_ANSWER_LENGTH = 120
  FALLBACK_STOP_WORDS = %w[about also been does from have here into just like more most only page some such than that
                           their them then there they this what when where which will with your].freeze
  # Sources are page-title links, never numbers after each part: customers cannot tell what "[1]" means.
  # The chat widget draws them under the bubble from this content attribute; other channels get them as text lines.
  SOURCES_ATTRIBUTE_KEY = 'captain_sources'.freeze

  attr_reader :parts

  def self.from_response(response)
    return new([{ text: response.to_s, citation_indexes: [] }]) unless response.is_a?(Hash)

    response = response.with_indifferent_access
    return new(response[:response_parts]) if response.key?(:response_parts)

    new([{ text: response[:response], citation_indexes: [] }])
  end

  def initialize(response_parts)
    @parts = Array(response_parts).filter_map { |part| normalize_part(part) }
  end

  def plain_text
    parts.pluck('text').join("\n\n")
  end

  # The model sometimes cites nothing for an answer it clearly took from one page. Cite the page whose title shares
  # the most distinctive words with the answer (at least FALLBACK_MIN_SHARED_WORDS), so its link is not lost.
  def with_fallback_citation(citation_titles:, ignored_words: [])
    return self if citation_titles.blank? || parts.any? { |part| part['citation_indexes'].present? }

    index = fallback_citation_index(citation_titles, ignored_words)
    return self unless index

    cited = parts.map(&:dup)
    cited.last['citation_indexes'] = [index]
    self.class.new(cited)
  end

  # :structured leaves sources out of the text (the widget and playground show captain_sources); email, and the widget
  # when Show sources is off, keep markdown links; channels whose renderers drop link titles (WhatsApp, SMS,
  # Instagram…) get "title: url".
  def self.sources_format(conversation, sources_card: true)
    case conversation&.inbox&.channel_type
    when nil, 'Channel::WebWidget' then sources_card ? :structured : :markdown
    when 'Channel::Email' then :markdown
    else :plain
    end
  end

  def customer_message_content(citation_urls: {}, citation_titles: {}, sources_format: :markdown)
    body = plain_text
    links = sources(citation_urls: citation_urls, citation_titles: citation_titles)
    return body if links.empty? || sources_format == :structured

    "#{body}\n\n#{links.map { |link| source_line(link, sources_format) }.join("\n")}"
  end

  # [{ 'title', 'url' }] in the order the reply first cites them; links the reply already shows inline are left out.
  def sources(citation_urls: {}, citation_titles: {})
    cited_links(plain_text, citation_urls, citation_titles).first(MAX_SOURCE_LINKS).map { |url, title| { 'title' => title, 'url' => url } }
  end

  def to_a
    parts
  end

  private

  # The arrow keeps the lines readable in every reply language.
  def source_line(link, sources_format)
    return "→ #{link['title']}: #{link['url']}" if sources_format == :plain

    "→ [#{link['title'].tr('[]', '()')}](#{link['url'].gsub('(', '%28').gsub(')', '%29')})"
  end

  def cited_links(body, citation_urls, citation_titles)
    parts.flat_map { |part| part['citation_indexes'] }.each_with_object({}) do |index, links|
      url = citation_urls[index]
      next if url.blank? || links.key?(url) || body.include?(url)

      links[url] = citation_titles[index].presence || title_from_url(url)
    end
  end

  def fallback_citation_index(citation_titles, ignored_words)
    text = plain_text
    return if text.length < FALLBACK_MIN_ANSWER_LENGTH

    answer_words = distinctive_words(text, ignored_words)
    best_index, best_count = citation_titles.filter_map do |index, title|
      [index, (distinctive_words(title.to_s.split(/\s[|·–-]\s/).first, ignored_words) & answer_words).size]
    end.max_by(&:last)
    best_index if best_count.to_i >= FALLBACK_MIN_SHARED_WORDS
  end

  # Words of four or more letters, singular, so "purchases" in the answer matches "purchase" in a title.
  def distinctive_words(text, ignored_words)
    words = text.to_s.downcase.scan(/[[:alnum:]]{4,}/).map { |word| word.delete_suffix('s') }
    words.uniq - FALLBACK_STOP_WORDS - ignored_words.map { |word| word.to_s.downcase.delete_suffix('s') }
  end

  def title_from_url(url)
    uri = URI.parse(url)
    segment = uri.path.to_s.split('/').compact_blank.last
    segment ? segment.sub(/\A\d+-/, '').tr('-_', '  ').squish.capitalize : uri.host.to_s.delete_prefix('www.')
  rescue URI::InvalidURIError
    url
  end

  def normalize_part(part)
    return unless part.is_a?(Hash)

    part = part.with_indifferent_access
    return unless part[:text].is_a?(String)

    text = part[:text].strip
    return if text.blank?

    {
      'text' => text,
      'citation_indexes' => Array(part[:citation_indexes]).select do |citation_index|
        citation_index.is_a?(Integer) && citation_index.positive?
      end.uniq
    }
  end
end

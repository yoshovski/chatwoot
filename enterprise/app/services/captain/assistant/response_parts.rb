class Captain::Assistant::ResponseParts
  MESSAGE_ATTRIBUTE_KEY = 'captain_v2_response_parts'.freeze
  MAX_SOURCE_LINKS = 3
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

  def without_citations
    self.class.new(parts.map { |part| part.merge('citation_indexes' => []) })
  end

  # :structured leaves sources out of the text (the widget and playground show captain_sources); email keeps markdown
  # links; channels whose renderers drop link titles (WhatsApp, SMS, Instagram…) get "title: url".
  def self.sources_format(conversation)
    case conversation&.inbox&.channel_type
    when nil, 'Channel::WebWidget' then :structured
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

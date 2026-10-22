class Captain::Assistant::ResponseParts
  MESSAGE_ATTRIBUTE_KEY = 'captain_v2_response_parts'.freeze
  MAX_SOURCE_LINKS = 3

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

  # Sources go on one closing line of page-title links instead of numbers after each part: customers
  # cannot tell what "[1]" means. The arrow keeps the line readable in every reply language and channel.
  def customer_message_content(citation_urls: {}, citation_titles: {})
    body = plain_text
    links = cited_links(body, citation_urls, citation_titles)
    return body if links.empty?

    line = links.first(MAX_SOURCE_LINKS).map { |url, title| "[#{title.tr('[]', '()')}](#{url.gsub('(', '%28').gsub(')', '%29')})" }
    "#{body}\n\n→ #{line.join(' · ')}"
  end

  def to_a
    parts
  end

  private

  # url => title, in the order the reply first cites them; links the reply already shows inline are left out.
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

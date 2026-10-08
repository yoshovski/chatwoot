# frozen_string_literal: true

class Captain::Conversation::ReplySanitizer
  MARKDOWN_LINK_REGEX = /\[([^\]]+)\]\(([^\)\s]+)(?:\s+["'][^"']*["'])?\)/
  AUTOLINK_REGEX = %r{<(https?://[^>]+)>}i
  # A URL written out in the text, not the target of a markdown link or an autolink.
  BARE_URL_REGEX = %r{(?<!\]\()(?<!<)https?://[^\s<>()\[\]"']+}i

  attr_reader :assistant

  def initialize(assistant:)
    @assistant = assistant
  end

  def sanitize_prose(content)
    return '' if content.blank?

    text = content.dup
    text = strip_images(text)
    text = filter_bare_urls(filter_autolinks(filter_markdown_links(text)))
    text = cleanup_prose_formatting(text)
    text.strip
  end

  def filter_citation_urls(citation_urls)
    return {} if citation_urls.blank?
    return citation_urls unless citation_urls.is_a?(Hash)

    citation_urls.select do |_idx, url|
      allowed_link_url?(url)
    end
  end

  def allowed_link_url?(url)
    allowed_url?(url, link_allowlist)
  end

  def allowed_image_url?(url)
    allowed_url?(url, image_allowlist)
  end

  def link_allowlist
    @link_allowlist ||= assistant.link_allowlist
  end

  def image_allowlist
    @image_allowlist ||= assistant.image_allowlist
  end

  private

  def allowed_url?(url, allowlist)
    return false if url.blank? || allowlist.blank?

    url_str = clean_url(url)
    return false if url_str.blank?

    allowlist.any? do |pattern|
      pattern_str = pattern.to_s.strip
      next false if pattern_str.blank?

      url_matches_pattern?(url_str, pattern_str)
    end
  rescue StandardError
    false
  end

  def url_matches_pattern?(url, pattern)
    return true if url.casecmp?(pattern) || url.casecmp?(pattern.chomp('/'))

    if pattern.end_with?('/')
      url.downcase.start_with?(pattern.downcase)
    else
      url.downcase.start_with?("#{pattern.downcase}/") || (pattern.exclude?('?') && url.downcase.start_with?("#{pattern.downcase}?"))
    end
  end

  def clean_url(url)
    url.to_s.strip.sub(/[.,;!?]+$/, '')
  end

  def strip_images(text)
    text.gsub(/!\[[^\]]*\](?:\([^\)]*\))?/, '')
        .gsub(%r{<img\b[^>]*/?>}i, '')
  end

  def filter_markdown_links(text)
    text.gsub(MARKDOWN_LINK_REGEX) do
      full_match, link_text, url = Regexp.last_match.values_at(0, 1, 2)
      allowed_link_url?(url) ? full_match : link_text
    end
  end

  def filter_autolinks(text)
    text.gsub(AUTOLINK_REGEX) do
      allowed_link_url?(Regexp.last_match(1)) ? Regexp.last_match(0) : ''
    end
  end

  # The widget turns written-out URLs into links too. Keep the sentence's punctuation when one is dropped.
  def filter_bare_urls(text)
    text.gsub(BARE_URL_REGEX) do |url|
      allowed_link_url?(url) ? url : url[/[.,;:!?]+\z/].to_s
    end
  end

  def cleanup_prose_formatting(text)
    # Turn '*' and '+' list markers into '-'
    text = text.gsub(/^(\s*)[*+][ \t]+/, '\1- ')

    # Remove heading markers (# through ######) at the beginning of lines
    text = text.gsub(/^(\s*)\#{1,6}[ \t]+/, '\1')

    # Replace em dash and en dash punctuation with comma
    text = text.gsub(/[ \t]*[—–][ \t]*/, ', ')

    # Clean up punctuation spacing if tags were stripped
    text = text.gsub(/:\s*([.!?,])/, '\1')
               .gsub(/[ \t]+([.!?,])/, '\1')
               .gsub(/,\s*,+/, ',')
               .gsub(/^,\s*/, '')
               .gsub(/[ \t]{2,}/, ' ')

    # Limit consecutive blank lines to at most two newlines
    text.gsub("\r\n", "\n").gsub(/\n{3,}/, "\n\n")
  end
end

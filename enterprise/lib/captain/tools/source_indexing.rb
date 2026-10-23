# frozen_string_literal: true

# Numbers every knowledge and product result a tool returns, so each reply part can
# name the results it relied on (citation_indexes). Agents see those sources in the
# message's generation details; customers only get links for sources with a trusted
# URL: a Sources card in the widget when Show sources is on, links in the reply otherwise.
module Captain::Tools::SourceIndexing
  EXCERPT_LENGTH = 280
  MATCHED_EXCERPT_LENGTH = 400

  def source_index_for(tool_context, reference, detail)
    details = tool_context.state[Captain::Assistant::CITATION_DETAILS_STATE_KEY] ||= {}
    details[reference] = details.fetch(reference, {}).merge(detail.compact)

    sources = tool_context.state[Captain::Assistant::CITATION_SOURCES_STATE_KEY] ||= {}
    sources.key(reference) || sources.size.next.tap { |index| sources[index] = reference }
  end

  def source_excerpt(text, length: EXCERPT_LENGTH)
    plain_text(text).squish.truncate(length).presence
  end

  # The part of a long document passage that matches the search, so agents see why it was found
  # instead of the passage's first lines (often a page's menu).
  def matched_excerpt(text, query)
    terms = query.to_s.downcase.scan(/[[:alnum:]]{3,}/).uniq
    sentences = plain_text(citation_body(text)).split(/(?<=[.!?])\s+|\n+/).map(&:squish).compact_blank
    start = sentences.each_index.max_by { |index| [terms.count { |term| sentences[index].downcase.include?(term) }, -index] }
    source_excerpt(sentences.drop(start.to_i).join(' '), length: MATCHED_EXCERPT_LENGTH)
  end

  private

  # Evidence previews must show the body, not a repeated breadcrumb, date or separator.
  def citation_body(text)
    lines = text.to_s.lines
    lines.shift if lines.first.to_s.include?(' > ')
    lines.reject do |line|
      line.match?(/\A\s*(?:\#{1,6}\s|\*{0,2}Effective Date:)/i) || line.strip.match?(/\A[-*_\s]{3,}\z/)
    end.join
  end

  # Markdown links and images keep only their text; emphasis, heading and list markers go.
  def plain_text(text)
    text.to_s.gsub(/!?\[([^\]]*)\]\([^)]*\)/, '\\1').gsub(/(\*\*|__)(.+?)\1/, '\\2').gsub(/^\s*(?:#+|[-*])\s+/, '')
  end
end

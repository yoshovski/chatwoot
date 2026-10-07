# frozen_string_literal: true

# Numbers every knowledge and product result a tool returns, so each reply part can
# name the results it relied on (citation_indexes). Agents see those sources in the
# message's generation details; customers only get links for sources with a trusted
# URL, and only when citations are enabled.
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
    sentences = plain_text(text).split(/(?<=[.!?])\s+|\n+/).map(&:squish).compact_blank
    start = sentences.each_index.max_by { |index| [terms.count { |term| sentences[index].downcase.include?(term) }, -index] }
    source_excerpt(sentences.drop(start.to_i).join(' '), length: MATCHED_EXCERPT_LENGTH)
  end

  private

  # Markdown links and images keep only their text; emphasis, heading and list markers go.
  def plain_text(text)
    text.to_s.gsub(/!?\[([^\]]*)\]\([^)]*\)/, '\\1').gsub(/(\*\*|__)(.+?)\1/, '\\2').gsub(/^\s*(?:#+|[-*])\s+/, '')
  end
end

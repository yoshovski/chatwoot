# frozen_string_literal: true

# Numbers every knowledge and product result a tool returns, so each reply part can
# name the results it relied on (citation_indexes). Agents see those sources in the
# message's generation details; customers only get links for sources with a trusted
# URL, and only when citations are enabled.
module Captain::Tools::SourceIndexing
  EXCERPT_LENGTH = 280

  def source_index_for(tool_context, reference, detail)
    details = tool_context.state[Captain::Assistant::CITATION_DETAILS_STATE_KEY] ||= {}
    details[reference] = details.fetch(reference, {}).merge(detail.compact)

    sources = tool_context.state[Captain::Assistant::CITATION_SOURCES_STATE_KEY] ||= {}
    sources.key(reference) || sources.size.next.tap { |index| sources[index] = reference }
  end

  def source_excerpt(text)
    text.to_s.gsub(/^\s*(?:#+|[-*])\s+/, '').squish.truncate(EXCERPT_LENGTH).presence
  end
end

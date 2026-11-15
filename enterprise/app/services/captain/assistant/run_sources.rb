# Every knowledge and product result of one AI agent run, in source index order, except unused low-relevance hits.
# A source is used when a reply part cites its index or the reply shows it as a product card. A reply that cites
# nothing (a scenario agent, an older prompt) still marks the sources whose wording it repeats, as used_by overlap.
# Recorded on the agent session of a conversation, and shown per reply in the AI agent test.
class Captain::Assistant::RunSources
  # A reply sentence of at least this many words, mostly found in a source's text, shows the source was used.
  OVERLAP_MIN_WORDS = 8
  OVERLAP_SHARE = 0.7

  def initialize(run_result)
    @run_result = run_result
  end

  def to_a
    references = context.dig(:state, Captain::Assistant::CITATION_SOURCES_STATE_KEY).to_h.transform_keys(&:to_i)
    details = context.dig(:state, Captain::Assistant::CITATION_DETAILS_STATE_KEY).to_h
    overlapping = overlapping_references(references, details)
    used_references = cited_references(references) | card_references(references.values) | overlapping

    references.sort.filter_map do |index, reference|
      detail = details[reference].to_h.symbolize_keys
      used = used_references.include?(reference)
      next if !used && detail[:low_relevance]

      { index: index, reference: reference, used: used, used_by: ('overlap' if overlapping.include?(reference)),
        **detail.slice(:kind, :title, :excerpt, :url, :faq_id, :document_id, :document_title) }.compact
    end
  end

  private

  def context
    @run_result.context || {}
  end

  # Sources containing most words of a reply sentence of at least eight words, for replies that cite nothing.
  def overlapping_references(references, details)
    return [] if cited_references(references).any? || reply_sentences.empty?

    references.values.select do |reference|
      excerpt = words(details[reference].to_h.symbolize_keys[:excerpt]).to_set
      reply_sentences.any? { |sentence| sentence.count { |word| excerpt.include?(word) } >= sentence.size * OVERLAP_SHARE }
    end
  end

  def reply_sentences
    @reply_sentences ||= Captain::Assistant::ResponseParts.from_response(@run_result.output).plain_text.split(/(?<=[.!?])\s+/)
                                                          .map { |sentence| words(sentence) }
                                                          .select { |sentence| sentence.size >= OVERLAP_MIN_WORDS }
  end

  def words(text) = text.to_s.downcase.scan(/[[:alnum:]%]+/)

  def cited_references(references)
    Captain::Assistant::ResponseParts.from_response(@run_result.output).to_a
                                     .flat_map { |part| part['citation_indexes'] }
                                     .filter_map { |index| references[index] }
  end

  def card_references(references)
    output = @run_result.output
    handles = output.is_a?(Hash) ? Array(output.with_indifferent_access[:product_handles]) : []
    references.select do |reference|
      reference.to_s.start_with?('product:') && handles.any? { |handle| handle.to_s.casecmp?(reference.delete_prefix('product:')) }
    end
  end
end

class Captain::Knowledge::FaqMatches
  MATCH_SCORE = 0.7
  MATCH_LIMIT = 5

  def initialize(assistant)
    @assistant = assistant
  end

  def candidates(relation, query)
    return published_matches(relation, query) if relation.klass == Captain::AssistantResponse

    # Suggestions are not published to Dify. Rank their local text before the LLM identity check.
    tokens = query.scan(/[[:alnum:]]+/).uniq.map { |token| "#{token}:*" }.join(' | ')
    return [] if tokens.empty?

    vector = "to_tsvector('simple', question || ' ' || answer)"
    rank = ApplicationRecord.sanitize_sql_array(["ts_rank_cd(#{vector}, to_tsquery('simple', ?)) DESC", tokens])
    relation.where("#{vector} @@ to_tsquery('simple', ?)", tokens).order(Arel.sql(rank)).limit(MATCH_LIMIT).to_a
  end

  private

  def published_matches(relation, query)
    passages = Captain::Knowledge::Search.new(@assistant).search(query, kinds: ['faq'])
    passages.select { |passage| passage.score >= MATCH_SCORE }.filter_map(&:record) & relation.to_a
  end
end

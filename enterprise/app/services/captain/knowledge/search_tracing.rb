module Captain::Knowledge::SearchTracing
  def search_prepared(query, kinds: nil)
    Captain::Tracing.operation('captain.knowledge.search', assistant: @assistant, type: 'retriever', input: { query: query, kinds: kinds }) do |span|
      passages = super
      span&.set_attribute('langfuse.observation.metadata.result_count', passages.size)
      Captain::Tracing.result(span, passages.map { |passage| { source: passage.source_reference, score: passage.score, content: passage.content } })
      passages
    end
  end
end

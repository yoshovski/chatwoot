# Classifies and rewrites one unclassified gap, merges it into a similar gap, and asks for a draft answer when a
# person already replied. Used by ClassifyJob and the backfill task.
class Captain::KnowledgeGaps::Classification
  def initialize(gap)
    @gap = gap
  end

  # Returns the gap that holds the question afterwards, or nil when the gap was already classified.
  def perform
    return unless @gap.unclassified?

    result = Captain::KnowledgeGaps::Classifier.for_gap(@gap).classify
    @gap.update!(kind: result.kind, question: result.question, topic: result.topic, language: result.language,
                 intent: result.intent, embedding: embedding(result.question), classified_at: Time.current)
    gap = Captain::KnowledgeGaps::Merger.new(@gap).merge!
    Captain::KnowledgeGaps::DraftAnswer.new(gap).perform
    gap
  end

  private

  def embedding(question)
    Captain::Llm::EmbeddingService.new(account_id: @gap.account_id).get_embedding(question).presence
  rescue Captain::Llm::EmbeddingService::EmbeddingsError => e
    Rails.logger.warn "[Captain][KnowledgeGaps] embedding failed gap_id=#{@gap.id} error=#{e.class.name}"
    nil
  end
end

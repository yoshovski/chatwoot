# Merges a freshly classified gap into the nearest open-or-closed gap of the same assistant and kind (and intent, for
# action requests) when their rewritten questions mean the same. The older gap keeps its question, topic and status;
# the newer one's occurrences move over (one per conversation) and the newer gap is deleted.
class Captain::KnowledgeGaps::Merger
  # Cosine distance between the embedded rewritten questions. 0.18 keeps paraphrases together and different products
  # or policies apart on text-embedding-3-small.
  DISTANCE_THRESHOLD = 0.18

  def initialize(gap)
    @gap = gap
  end

  # Returns the gap that holds the question afterwards: the target, or the gap itself when nothing is close enough.
  def merge!
    target = nearest
    return @gap unless target

    Captain::KnowledgeGap.transaction do
      [@gap, target].sort_by(&:id).each(&:lock!)
      move_occurrences(target)
      target.update!(occurrences_count: target.occurrences.count, last_seen_at: [target.last_seen_at, @gap.last_seen_at].max,
                     status: merged_status(target), draft_answer: target.draft_answer.presence || @gap.draft_answer)
      @gap.destroy!
    end
    target
  end

  private

  def candidates
    scope = @gap.assistant.knowledge_gaps.where(kind: @gap.kind).where.not(id: @gap.id)
    @gap.action_request? ? scope.where(intent: @gap.intent) : scope
  end

  # Without an embedding (the embedding call failed) only the same rewritten question merges.
  def nearest
    if @gap.embedding.nil?
      normalized = Captain::KnowledgeGaps::Normalizer.call(@gap.question)
      return candidates.find { |gap| Captain::KnowledgeGaps::Normalizer.call(gap.question) == normalized }
    end

    Captain::KnowledgeGap.transaction do
      # Exact search: an approximate index can miss neighbours after the assistant and kind filters.
      Captain::KnowledgeGap.connection.execute('SET LOCAL enable_indexscan = off')
      candidates.where.not(embedding: nil).nearest_neighbors(:embedding, @gap.embedding, distance: 'cosine').first(1)
                .find { |gap| gap.neighbor_distance <= DISTANCE_THRESHOLD }
    end
  end

  def move_occurrences(target)
    @gap.occurrences.where(conversation_id: target.occurrences.select(:conversation_id)).delete_all
    @gap.occurrences.update_all(knowledge_gap_id: target.id, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  # Same rule as the recorder: a dismissed gap stays dismissed, an answered one reopens when the question comes back.
  def merged_status(target)
    target.answered? && @gap.open? ? :open : target.status
  end
end

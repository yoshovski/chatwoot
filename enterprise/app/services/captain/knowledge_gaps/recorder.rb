# Records one customer question the AI couldn't answer. A conversation counts once per gap; a dismissed gap stays
# dismissed, an answered gap reopens because the saved answer didn't help.
class Captain::KnowledgeGaps::Recorder
  def initialize(assistant:, conversation:, question:, reason:, message_id: nil)
    @assistant = assistant
    @conversation = conversation
    @question = question.to_s.squish.truncate(Captain::KnowledgeGap::QUESTION_LIMIT)
    @reason = reason
    @message_id = message_id
  end

  def record
    normalized = Captain::KnowledgeGaps::Normalizer.call(@question)
    return if normalized.blank?

    gap = @assistant.knowledge_gaps.create_or_find_by!(normalized_question: normalized) do |new_gap|
      new_gap.question = @question
      new_gap.last_seen_at = Time.current
    end
    gap.with_lock { add_occurrence(gap) }
    gap
  end

  private

  def add_occurrence(gap)
    attributes = { question: @question, last_seen_at: Time.current }
    attributes[:status] = :open if gap.answered?
    unless gap.occurrences.exists?(conversation_id: @conversation.id)
      gap.occurrences.create!(conversation: @conversation, message_id: @message_id, reason: @reason)
      attributes[:occurrences_count] = gap.occurrences_count + 1
    end
    gap.update!(attributes)
  end
end

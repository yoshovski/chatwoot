# Records one customer question the AI couldn't answer. A conversation counts once per gap; a dismissed gap stays
# dismissed, an answered gap reopens because the saved answer didn't help.
# The raw text stays on the occurrence. A text seen before joins the gap it ended in (also after a merge); a new
# text starts an unclassified gap that ClassifyJob rewrites and merges into the nearest similar one.
class Captain::KnowledgeGaps::Recorder
  def initialize(assistant:, conversation:, question:, reason:, message_id: nil)
    @assistant = assistant
    @conversation = conversation
    @question = question.to_s.squish.truncate(Captain::KnowledgeGap::QUESTION_LIMIT)
    @reason = reason
    @message_id = message_id
  end

  def record
    @normalized = Captain::KnowledgeGaps::Normalizer.call(@question)
    return if @normalized.blank?

    gap = known_gap || @assistant.knowledge_gaps.create_or_find_by!(normalized_question: @normalized) do |new_gap|
      new_gap.question = @question
      new_gap.last_seen_at = Time.current
    end
    gap.with_lock { add_occurrence(gap) }
    Captain::KnowledgeGaps::ClassifyJob.perform_later(gap) if gap.unclassified?
    gap
  end

  private

  def known_gap
    @assistant.knowledge_gaps.joins(:occurrences)
              .find_by(captain_knowledge_gap_occurrences: { account_id: @assistant.account_id, normalized_question: @normalized })
  end

  def add_occurrence(gap)
    attributes = { last_seen_at: Time.current }
    attributes[:question] = @question if gap.unclassified?
    attributes[:status] = :open if gap.answered?
    unless gap.occurrences.exists?(conversation_id: @conversation.id)
      gap.occurrences.create!(conversation: @conversation, message_id: @message_id, reason: @reason,
                              question: @question, normalized_question: @normalized)
      attributes[:occurrences_count] = gap.occurrences_count + 1
    end
    gap.update!(attributes)
  end
end

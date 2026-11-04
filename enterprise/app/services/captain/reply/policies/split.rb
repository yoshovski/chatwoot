# Parts the model listed in separate_parts start a new bubble, at most MAX_BUBBLES per reply. Email and the follow-up
# form keep one message. The indexes are the model's own part indexes, so a welcome before them changes nothing, and the
# welcome always opens the first answer bubble: a start at the first answer part (the model counting from the welcome,
# or listing the part after a repeated welcome the draft dropped) splits nothing.
class Captain::Reply::Policies::Split < Captain::Reply::Policies::Base
  MAX_BUBBLES = 3

  def apply
    return if context.followup_form_requested || context.email?

    parts = workspace.segments.first.parts
    starts = starts(parts)
    return if starts.empty?

    groups = [0, *starts, parts.size].each_cons(2).map { |from, to| parts[from...to] }
    workspace.segments = groups.each_with_index.map { |group, index| bubble(group, last: index == groups.size - 1) }
  end

  private

  # Each bubble lists only the sources its own parts cite; the knowledge media go to the last one.
  def bubble(parts, last:)
    workspace.answer_segment(parts, sources: workspace.sources(parts), media: last)
  end

  # The welcome and the first answer part always open the first bubble.
  def starts(parts)
    first_answer = parts.index { |part| part.kind != :greeting }.to_i
    parts.each_index.select { |index| index > first_answer && draft.separate_part_indexes.include?(parts[index].model_index) }
         .first(MAX_BUBBLES - 1)
  end
end

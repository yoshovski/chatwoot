# The closing question: the last sentence of the answer when it is a question (any part's, for a qualification
# question). On the widget it gets its own bubble (Captain::Behaviour::SEPARATE_FOLLOW_UP_ON_WIDGET), and a
# qualification question always does. A short greeting such as "Hi! How can I help?" stays one bubble, and so does the
# empty-answer fallback. With cards the question keeps its place (see Cards); the follow-up form takes it (see LeadForm).
class Captain::Reply::Policies::FollowUp < Captain::Reply::Policies::Base
  # The last sentence of the prose when it is a question that follows at least one other sentence.
  TRAILING_QUESTION = /(?:\n\s*\n|(?<=[.!?])\s+)([^\n.!?]+\?)\s*\z/
  MIN_SEPARATED_ANSWER_WORDS = 4

  def self.question_in(text) = text[TRAILING_QUESTION, 1] || (text if text.end_with?('?'))

  def apply
    answer = workspace.segments[workspace.answer_index]
    content = workspace.text(answer)
    question = workspace.question = closing_question(answer.parts, content)
    workspace.has_closing_question = question.present? || content.strip.end_with?('?')
    workspace.close_with_question! if question && !context.followup_form_requested && separate?(question[:text])
  end

  private

  def closing_question(parts, content)
    candidates = draft.qualification_question ? parts.each_index.to_a : [parts.size - 1]
    candidates.reverse_each do |index|
      question = self.class.question_in(parts[index].text)
      return { text: question, part_index: index } if question
    end
    question = content[TRAILING_QUESTION, 1]
    { text: question, part_index: parts.rindex { |part| part.text.include?(question) } } if question
  end

  def separate?(question)
    context.widget? &&
      (draft.qualification_question || (Captain::Behaviour::SEPARATE_FOLLOW_UP_ON_WIDGET && !workspace.contains_cards? && answer_before?(question)))
  end

  def answer_before?(question)
    workspace.formatted_prose.sub(question, '').scan(/[[:alnum:]]+/).size >= MIN_SEPARATED_ANSWER_WORDS
  end
end

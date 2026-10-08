# frozen_string_literal: true

class Captain::Conversation::HandoffSafetyNet
  DEAD_END_PATTERN = Regexp.union(
    /(?:\bi\s+)?\b(?:cannot|can\s+not|can't|do\s+not|don't)\s+(?:provide|have|find|confirm|access|determine)\b/i,
    /\bi\s+(?:am|'m)\s+(?:unable|not\s+able)\s+to\b/i,
    /\b(?:let\s+me\s+know\s+if|would\s+you\s+like)\s+me\s+to\s+(?:search|look|check)\b/i
  )
  ALTERNATIVE_PATTERN = /\b(?:but|however|instead|we\s+(?:do\s+)?have|we\s+carry)\b/i
  ALTERNATIVE_WINDOW_CHARS = 180

  ORDER_PROBLEM_KEYWORDS = [
    'damaged', 'broken', 'missing', 'wrong item', 'never arrived', 'refund', 'return it', 'late delivery', 'tracking problem'
  ].freeze

  ASKS_FOR_PERSON_KEYWORDS = [
    'speak to', 'talk to', 'real person', 'human agent'
  ].freeze

  DEFAULT_KEYWORDS = (ORDER_PROBLEM_KEYWORDS + ASKS_FOR_PERSON_KEYWORDS).freeze

  attr_reader :assistant, :customer_message, :answer

  def initialize(assistant:, customer_message:, answer:)
    @assistant = assistant
    @customer_message = customer_message
    @answer = answer
  end

  def triggered?
    customer_message_matches? || dead_end_answer?
  end

  private

  def customer_message_matches?
    text = customer_message_text
    return false if text.blank?

    keywords.any? do |phrase|
      pattern = /\b#{Regexp.escape(phrase.strip).gsub('\ ', '\s+')}\b/i
      pattern.match?(text)
    end
  end

  def dead_end_answer?
    text = answer.to_s.strip
    return false if text.blank?

    first_sent = first_sentence(text)
    return false unless DEAD_END_PATTERN.match?(first_sent)

    search_window = text[0...(first_sent.length + ALTERNATIVE_WINDOW_CHARS)]
    !ALTERNATIVE_PATTERN.match?(search_window)
  end

  def first_sentence(text)
    text.split(/(?<=[.!?])(?:\s+|\z)|\n+/).first.to_s.strip
  end

  def keywords
    configured = assistant&.config&.[]('handoff_safety_net_keywords')
    return configured if configured.is_a?(Array) && configured.present?

    DEFAULT_KEYWORDS
  end

  def customer_message_text
    case customer_message
    when Message
      customer_message.content.to_s
    else
      customer_message.to_s
    end
  end
end

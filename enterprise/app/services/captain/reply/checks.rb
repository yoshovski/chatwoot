# Checks the finished plan of one reply against the reply rules, repairs what breaks them and logs every repair
# (and the repeated welcome the draft removed), so the customer never sees a welcome twice even when the model or a
# policy gets it wrong.
class Captain::Reply::Checks
  RULES = %i[single_greeting media_once no_repeated_sentences single_question no_empty_segments max_text_bubbles].freeze
  MAX_TEXT_BUBBLES = 3
  MIN_REPEATED_SENTENCE_WORDS = 4
  PROSE_KINDS = %w[greeting answer question].freeze
  # Source lines and media lines are not sentences.
  NON_PROSE_LINE = /\A\s*(?:→\s|\[[^\]]*\]\([^)\s]+\)\s*\z)/

  def initialize(context, draft)
    @context = context
    @draft = draft
  end

  def repair(plan)
    record(:duplicate_welcome, @draft.welcome_guard) if @draft.welcome_guard
    RULES.each { |rule| send(rule, plan) }
    plan
  end

  private

  # At most one greeting, and none when an earlier reply already greeted the customer.
  def single_greeting(plan)
    greetings = plan.segments.select { |segment| segment.kind == 'greeting' }
    return if greetings.empty?

    if already_greeted?
      greetings.each { |greeting| drop_greeting(plan, greeting) }
      record(:single_greeting, 'dropped_repeat')
    elsif greetings.size > 1
      greetings.drop(1).each { |greeting| drop_greeting(plan, greeting) }
      record(:single_greeting, 'dropped_extra')
    end
  end

  # The run says this is not the first reply, or an earlier message carried a greeting (an earlier reply or this
  # reply's early welcome, which is then the conversation's only greeting).
  def already_greeted?
    return true if @context.first_ai_reply == false
    return false unless @context.conversation

    Captain::Reply::EarlyWelcome.sent?(@context.conversation)
  end

  # An attached greeting is the start of the next bubble's text.
  def drop_greeting(plan, greeting)
    index = plan.segments.index(greeting)
    plan.segments.delete_at(index)
    return unless greeting.attach == :next

    following = plan.segments[index]
    plan.segments[index] = following.with(text: following.text.to_s.delete_prefix(greeting.text).sub(/\A\s+/, ''))
  end

  # A knowledge video or screenshot shows once per reply.
  def media_once(plan)
    seen = []
    rewrite_texts(plan, :media_once, 'dropped') do |text|
      lines = text.split("\n", -1)
      kept = lines.reject do |line|
        next false unless Captain::Knowledge::VideoLink.line?(line) || Captain::Knowledge::ScreenshotLink.line?(line)
        next true if seen.include?(line.strip)

        seen << line.strip
        false
      end
      kept.size == lines.size ? text : squeeze(kept.join("\n"))
    end
  end

  # A sentence of MIN_REPEATED_SENTENCE_WORDS or more words says it once: the later copy goes, in the text and in
  # the stored parts the model reads back as history.
  def no_repeated_sentences(plan)
    seen_in_text = []
    rewrite_texts(plan, :no_repeated_sentences, 'dropped') { |text| without_repeated_sentences(text, seen_in_text) }
    seen_in_parts = []
    plan.segments = plan.segments.map do |segment|
      next segment unless segment.prose?

      segment.with(parts: segment.parts.filter_map do |part|
        text = without_repeated_sentences(part.text, seen_in_parts)
        part.with(text: text) if text.present?
      end)
    end
  end

  def without_repeated_sentences(text, seen)
    dropped = false
    lines = text.split("\n", -1).map do |line|
      next line if line.match?(NON_PROSE_LINE)

      sentences = line.split(/(?<=[.!?])\s+/)
      kept = sentences.reject { |sentence| repeated?(sentence, seen) }
      dropped ||= kept.size < sentences.size
      kept.size == sentences.size ? line : kept.join(' ')
    end
    dropped ? squeeze(lines.join("\n")) : text
  end

  # Remembers the sentence when it is the first copy.
  def repeated?(sentence, seen)
    key = sentence.downcase.scan(/[[:alnum:]]+/)
    return false if key.size < MIN_REPEATED_SENTENCE_WORDS
    return true if seen.include?(key)

    seen << key
    false
  end

  # One question per reply, and it is the last thing asked: a second question bubble goes, and a bubble before the one
  # that asks loses the question sentences it ends with, also when they are worded differently.
  def single_question(plan)
    questions = plan.segments.select { |segment| segment.kind == 'question' }
    if questions.size > 1
      plan.segments -= questions.drop(1)
      record(:single_question, 'dropped')
    end
    strip_earlier_questions(plan)
  end

  def strip_earlier_questions(plan)
    bubbles = plan.segments.select { |segment| prose_bubble?(segment) }
    asking = bubbles.rindex { |segment| asks?(segment) }
    earlier = asking ? bubbles.first(asking).select { |segment| Captain::Reply::Question.trailing?(segment.text) } : []
    return if earlier.empty?

    plan.segments = plan.segments.map { |segment| earlier.include?(segment) ? without_question(segment) : segment }
    record(:single_question, 'stripped')
  end

  def prose_bubble?(segment) = segment.attach.nil? && PROSE_KINDS.include?(segment.kind) && segment.text.present?

  def asks?(segment) = segment.kind == 'question' || Captain::Reply::Question.trailing?(segment.text)

  # Also out of the stored parts the model reads back as history.
  def without_question(segment)
    *parts, last = segment.parts.to_a
    last_text = Captain::Reply::Question.without_trailing(last.text) if last
    parts << last.with(text: last_text) if last_text.present?
    segment.with(text: Captain::Reply::Question.without_trailing(segment.text), parts: segment.prose? ? parts : nil)
  end

  def no_empty_segments(plan)
    empty = plan.segments.select { |segment| empty?(segment) }
    return if empty.empty?

    plan.segments = plan.segments.each_with_index.filter_map do |segment, index|
      next if empty.include?(segment)

      # A segment attached to a dropped one stands on its own.
      empty.include?(plan.segments[index + 1]) && segment.attach == :next ? segment.with(attach: nil) : segment
    end
    record(:no_empty_segments, 'dropped')
  end

  def empty?(segment)
    PROSE_KINDS.include?(segment.kind) && segment.attach.nil? && segment.text.blank? && !segment.buttons?
  end

  # At most MAX_TEXT_BUBBLES greeting and answer bubbles; the rest joins the last one allowed.
  def max_text_bubbles(plan)
    bubbles = plan.segments.select { |segment| segment.attach.nil? && %w[greeting answer].include?(segment.kind) }
    return if bubbles.size <= MAX_TEXT_BUBBLES

    last, *extra = bubbles.drop(MAX_TEXT_BUBBLES - 1)
    merged = extra.reduce(last) { |joined, segment| joined_bubbles(joined, segment) }
    plan.segments = (plan.segments - extra).map { |segment| segment.equal?(last) ? merged : segment }
    record(:max_text_bubbles, 'merged')
  end

  def joined_bubbles(first, second)
    first.with(text: [first.text, second.text].compact_blank.join("\n\n"), parts: first.parts + second.parts,
               content_attributes: merged_sources(first, second))
  end

  def merged_sources(first, second)
    key = Captain::Assistant::ResponseParts::SOURCES_ATTRIBUTE_KEY
    sources = (Array(first.content_attributes&.dig(key)) + Array(second.content_attributes&.dig(key))).uniq
    sources.empty? ? first.content_attributes : first.content_attributes.to_h.merge(key => sources)
  end

  # Rewrites the text of every bubble (an attached segment's text is part of the next one) and logs once if any changed.
  def rewrite_texts(plan, rule, action)
    changed = false
    plan.segments = plan.segments.map do |segment|
      next segment if segment.attach == :next || PROSE_KINDS.exclude?(segment.kind) || segment.text.blank?

      text = yield(segment.text)
      next segment if text == segment.text

      changed = true
      segment.with(text: text)
    end
    record(rule, action) if changed
  end

  def squeeze(text) = text.gsub(/\n{3,}/, "\n\n").strip

  def record(rule, action)
    Rails.logger.info "[Captain][ReplyGuard] rule=#{rule} action=#{action} assistant_id=#{@context.assistant.id} " \
                      "conversation_id=#{@context.conversation&.id || 'none'}"
    return unless ChatwootApp.otel_enabled?

    OpenTelemetry::Trace.current_span.set_attribute("langfuse.observation.metadata.reply_guard_#{rule}", action.to_s)
  end
end

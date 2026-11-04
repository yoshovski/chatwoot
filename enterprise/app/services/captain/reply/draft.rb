# The model's reply as typed data. The only code that reads the model's Hash: everything after works on the draft.
# The welcome stays its own field; parts keep the index the model gave them (separate_parts counts these indexes).
# Schema v2 replies carry the closing question in `follow_up`: it becomes the last part (unless a normalized response
# already ends with it) and `follow_up` points at that part, so policies never search the prose for it.
Captain::Reply::Draft = Data.define(:welcome, :welcome_guard, :parts, :separate_part_indexes, :follow_up, :suggestions,
                                    :product_handles, :handoff_requested, :qualification_question, :agent_name, :raw) do
  # A first sentence this short that opens with a greeting word is a greeting, not part of the answer.
  self::MAX_GREETING_WORDS = 8
  self::GREETING_START = /\A(?:hi|hello|hey|welcome|greetings|good\s(?:morning|afternoon|evening)|thanks\sfor\sreaching\sout|hola|
                           buenos\sd[ií]as|bonjour|salut|hallo|guten\stag|ciao|buongiorno|ol[áa]|oi|hej)\b/x
  # Greeting words count as the same word, so "Hi there!" repeats the welcome "Hello and welcome!".
  self::GREETING_WORDS = %w[hi hello hey welcome greetings hola bonjour salut hallo ciao buongiorno olá ola oi hej].freeze
  self::SENTENCE_BREAK = /\A[ \t]*(?:[.,!?;:…\n]|\p{Extended_Pictographic}|\z)/
  self::LEADING_FILLER = /\A(?:[\s.,!?;:¡¿…–—-]|\p{Extended_Pictographic}|\u{FE0F})+/

  def self.from_response(response)
    hash = response.is_a?(Hash) ? response : {}
    welcome = welcome_text(response)
    parts, welcome_guard = without_repeated_welcome(model_parts(response), welcome)
    parts, follow_up = with_follow_up(parts, hash['follow_up'])
    qualification = follow_up ? follow_up.kind == 'qualification' : hash['lead_qualification_question'] == true
    new(welcome: welcome, welcome_guard: welcome_guard, parts: parts, separate_part_indexes: Array(hash['separate_parts']).grep(Integer),
        follow_up: follow_up, suggestions: hash['suggested_replies'], product_handles: hash['product_handles'],
        handoff_requested: hash['handoff_requested'] == true, qualification_question: qualification,
        agent_name: hash['agent_name'], raw: response)
  end

  def self.with_follow_up(parts, value)
    text = normalize([{ text: value['text'] }]).first&.text if value.is_a?(Hash)
    return [parts, nil] unless text

    part = parts.last
    unless part&.text == text
      part = Captain::Reply::Part.new(text: text, model_index: parts.empty? ? 0 : parts.last.model_index + 1)
      parts = [*parts, part]
    end
    [parts, Captain::Reply::FollowUp.new(text: text, kind: value['kind'], model_index: part.model_index)]
  end

  def self.model_parts(response)
    return normalize([{ text: response.to_s }]) unless response.is_a?(Hash)

    response = response.with_indifferent_access
    normalize(response.key?(:response_parts) ? response[:response_parts] : [{ text: response[:response] }])
  end

  # The AI welcome of a first reply; only replies with response_parts carry one.
  def self.welcome_text(response)
    return unless response.is_a?(Hash)

    response = response.with_indifferent_access
    normalize([{ text: response[:welcome] }]).first&.text if response.key?(:response_parts)
  end

  # Parts with blank text are skipped; the index counts the parts that remain, as separate_parts always has.
  def self.normalize(model_parts)
    Captain::Assistant::ResponseParts.new(model_parts).parts.each_with_index.map do |part, index|
      Captain::Reply::Part.new(text: part['text'], citation_indexes: part['citation_indexes'], model_index: index)
    end
  end

  # The model may still open its answer with the welcome or another greeting; never send the welcome twice. If nothing
  # of the answer would remain, the parts stay as the model wrote them. Returns the parts and 'dropped', 'stripped' or nil.
  def self.without_repeated_welcome(parts, welcome)
    return [parts, nil] if welcome.blank?

    first, *rest = parts
    text = repeated_welcome_remainder(first.text, welcome) if first
    return [parts, nil] if text.nil?

    stripped = Captain::Assistant::ResponseParts.new([{ text: text }]).parts.first
    return [[first.with(text: stripped['text']), *rest], 'stripped'] if stripped
    return [parts, nil] if rest.empty?

    # A dropped part's citations move to the next part.
    [[rest.first.with(citation_indexes: (first.citation_indexes + rest.first.citation_indexes).uniq), *rest.drop(1)], 'dropped']
  end

  # The text without the repeated welcome (blank when it is only the welcome), or nil when it doesn't repeat it.
  def self.repeated_welcome_remainder(text, welcome)
    welcome_words = words(welcome)
    return if welcome_words.empty?
    return '' if words(text) == welcome_words

    after_welcome = welcome_prefix_remainder(text, welcome_words)
    return after_welcome.sub(self::LEADING_FILLER, '') if after_welcome

    sentence, remainder = text.split(/(?<=[.!?])\s+|\n+/, 2)
    remainder.to_s.sub(self::LEADING_FILLER, '') if greeting_sentence?(sentence, welcome)
  end

  # The text after the welcome when the text opens with the whole welcome sentence ("Hello and welcome! To clear…"),
  # not when the welcome's words run on into the answer ("Hello and welcome to…").
  def self.welcome_prefix_remainder(text, welcome_words)
    return unless words(text).first(welcome_words.size) == welcome_words

    remainder = text[text.to_enum(:scan, /[[:alnum:]]+/).map { Regexp.last_match.end(0) }[welcome_words.size - 1]..]
    remainder if remainder.match?(self::SENTENCE_BREAK)
  end

  def self.greeting_sentence?(sentence, welcome)
    sentence_words = greeting_words(sentence).uniq
    return false if sentence_words.size > self::MAX_GREETING_WORDS || !words(sentence).join(' ').match?(self::GREETING_START)

    (sentence_words & greeting_words(welcome)).size * 2 >= sentence_words.size
  end

  # Lowercase words without punctuation or emoji.
  def self.words(text)
    text.to_s.downcase.scan(/[[:alnum:]]+/)
  end

  # Words with every greeting word as "hello".
  def self.greeting_words(text)
    words(text).map { |word| self::GREETING_WORDS.include?(word) ? 'hello' : word }
  end

  private_class_method :with_follow_up, :model_parts, :welcome_text, :normalize,
                       :without_repeated_welcome, :repeated_welcome_remainder, :welcome_prefix_remainder,
                       :greeting_sentence?, :words, :greeting_words

  def welcome_part = welcome.present? ? Captain::Reply::Part.new(text: welcome, kind: :greeting) : nil
end

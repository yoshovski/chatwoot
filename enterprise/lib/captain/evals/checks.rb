# Deterministic rules for one observed reply. Each check returns { name:, pass:, detail: }.
# A check in a suite is a name (`welcome_once`) or a one-key hash with its argument (`{ bubbles: { min: 1, max: 2 } }`).
module Captain::Evals::Checks # rubocop:disable Metrics/ModuleLength
  NAMES = %w[welcome_once starts_with_greeting no_repeated_sentences no_empty_bubbles bubbles question_bubble no_click_paths
             links_from_knowledge contains_video mentions_all language handoff route max_chars judge any_of].freeze
  NON_TEXT_TYPES = %w[form cards].freeze
  MARKDOWN_LINK = /!?\[([^\]]*)\]\(([^)\s]+)\)/
  URL = %r{https?://[^\s)\]>"']+}
  CLICK_PATH = /\b(?:dashboard|settings|admin|account|menu)\s*(?:>|→|»)\s*\S|\bgo to\s+[^.\n]+?\s(?:>|→|»)\s*\S/i
  # Numbered steps that walk an admin through settings screens instead of answering.
  ADMIN_STEP = /^\s*\d+[.)]\s+(?:go to|open|navigate to|click)\s+(?:the\s+)?(?:admin|settings|dashboard)\b/i
  STOPWORDS = {
    'en' => %w[the and you your is are to of for with this that can how it in on what],
    'de' => %w[der die das und sie ihr ist sind zu von mit für ein eine wie nicht auf können],
    'es' => %w[el la los las y que es de para con por un una cómo puede su en],
    'fr' => %w[le la les et vous est sont de pour avec un une comment pouvez votre dans],
    'it' => %w[il lo la gli le e che di per con un una come può sono nel],
    'nl' => %w[de het een en je u is zijn van voor met hoe niet op kunt],
    'pt' => %w[o a os as e que de para com um uma como pode seu em não]
  }.freeze

  module_function

  def run(spec, observation)
    name, argument = spec.is_a?(Hash) ? spec.first : [spec, nil]
    name = name.to_s
    raise ArgumentError, "Unknown check: #{name}" unless NAMES.include?(name)

    pass, detail = public_send(name, observation, argument)
    { name: name, pass: pass, detail: detail }
  end

  def welcome_once(observation, _argument = nil)
    sentences = sentences_of(full_text(observation)).map { |sentence| normalize(sentence) }
    repeated = repeated(sentences.select { |sentence| sentence.split.size >= 3 })
    welcomes = welcome_starts(observation)
    return [false, "repeated: #{repeated.first}"] if repeated.any?
    return [false, 'the first two sentences are the same'] if sentences.size > 1 && sentences[0] == sentences[1]
    return [false, "#{welcomes.size} welcomes: #{welcomes.join(' | ')}"] if welcomes.size > 1

    [true, nil]
  end

  # Greeting sentences that open a bubble or follow a sentence of the answer. "Hi there! Welcome to Acme." is one welcome.
  def welcome_starts(observation)
    text_messages(observation).flat_map do |text|
      sentences = sentences_of(text).map { |sentence| normalize(sentence) }
      sentences.each_with_index.select { |sentence, index| greeting?(sentence) && (index.zero? || !greeting?(sentences[index - 1])) }.map(&:first)
    end
  end

  def starts_with_greeting(observation, expected)
    first = sentences_of(text_messages(observation).first.to_s).first.to_s
    actual = greeting?(normalize(first))
    [actual == expected, "first sentence: #{first.strip.truncate(80)}"]
  end

  def no_repeated_sentences(observation, _argument = nil)
    repeated = repeated(sentences_of(full_text(observation)).map { |sentence| normalize(sentence) }.select { |sentence| sentence.split.size >= 4 })
    [repeated.empty?, repeated.first]
  end

  def no_empty_bubbles(observation, _argument = nil)
    empty = observation[:messages].count do |message|
      attributes = message['content_attributes'].to_h
      message['content'].blank? && attributes['items'].blank? && attributes['cards'].blank? && message['content_type'] != 'form'
    end
    [empty.zero?, "#{empty} empty"]
  end

  def bubbles(observation, range)
    count = text_messages(observation).size
    [count.between?(range.fetch('min', 0), range.fetch('max', Float::INFINITY)), "#{count} text bubbles"]
  end

  # The follow-up question has its own last bubble, and the bubble before it doesn't ask it too.
  def question_bubble(observation, expected)
    *earlier, last = text_messages(observation)
    question = last.to_s.strip
    actual = earlier.any? && question.end_with?('?') && sentences_of(question).size == 1 && earlier.last.exclude?(question)
    [actual == expected, "last bubble: #{question.truncate(80)}"]
  end

  def no_click_paths(observation, _argument = nil)
    text = full_text(observation)
    match = text[CLICK_PATH] || text[ADMIN_STEP]
    [match.nil?, match]
  end

  def links_from_knowledge(observation, _argument = nil)
    allowed = observation[:fixture_urls].to_a
    allowlist = observation[:link_allowlist].to_a - ['*']
    foreign = urls(observation).reject { |url| allowed.include?(url) || allowlist.any? { |prefix| url.start_with?(prefix) } }
    [foreign.empty?, foreign.join(', ').presence]
  end

  def contains_video(observation, expected)
    actual = full_text(observation).lines.any? { |line| Captain::Knowledge::VideoLink.line?(line.strip) }
    [actual == expected, actual ? 'video present' : 'no video']
  end

  # Every term appears in the reply (case-insensitive), e.g. each browser a how-to covers.
  def mentions_all(observation, terms)
    text = full_text(observation).downcase
    missing = Array(terms).reject { |term| text.include?(term.to_s.downcase) }
    [missing.empty?, missing.any? ? "missing: #{missing.join(', ')}" : nil]
  end

  # Passes when one of the checks passes: a reply may solve the case in more than one acceptable way.
  def any_of(observation, specs)
    results = specs.map { |spec| run(spec, observation) }
    [results.any? { |result| result[:pass] }, results.map { |result| "#{result[:name]}: #{result[:detail]}" }.join('; ')]
  end

  def language(observation, expected)
    words = normalize(full_text(observation)).split
    scores = STOPWORDS.transform_values { |stopwords| words.count { |word| stopwords.include?(word) } }
    detected = scores.max_by { |_code, score| score }&.first
    [detected == expected.to_s, "detected #{detected}"]
  end

  def handoff(observation, expected)
    [observation[:handoff] == expected, "handoff #{observation[:handoff]}"]
  end

  def route(observation, expected)
    actual = observation.dig(:route, 'intent')
    [actual == expected.to_s, "route #{actual} (#{observation.dig(:route, 'reason')})"]
  end

  def max_chars(observation, limit)
    length = text_messages(observation).sum(&:length)
    [length <= limit, "#{length} chars"]
  end

  # Only with JUDGE=1; the runner passes the model's verdict in the observation.
  def judge(observation, rubric)
    verdict = observation.dig(:judgements, rubric)
    return [true, 'skipped (JUDGE not set)'] if verdict.nil?

    [verdict == 'PASS', verdict]
  end

  def text_messages(observation)
    observation[:messages].reject { |message| NON_TEXT_TYPES.include?(message['content_type']) }.filter_map { |message| message['content'].presence }
  end

  def full_text(observation) = text_messages(observation).join("\n")

  def urls(observation)
    text_messages(observation).flat_map { |text| text.scan(URL) }.map { |url| url.sub(/[.,;:!?]+\z/, '') }.uniq
  end

  def sentences_of(text)
    text.to_s.split(/(?<=[.!?])\s+|\n+/).map(&:strip).reject(&:blank?)
  end

  # Links become their text, then lowercase words without punctuation.
  def normalize(text)
    text.to_s.gsub(MARKDOWN_LINK, '\1').downcase.gsub(/[^[:alnum:]\s]/, ' ').squish
  end

  def greeting?(normalized_sentence)
    normalized_sentence.match?(Captain::Reply::Draft::GREETING_START)
  end

  def repeated(items) = items.tally.select { |_item, count| count > 1 }.keys
end

class Captain::Assistant::ResponseParts
  MESSAGE_ATTRIBUTE_KEY = 'captain_v2_response_parts'.freeze
  MAX_SOURCE_LINKS = 3
  FALLBACK_MIN_SHARED_WORDS = 2
  FALLBACK_MIN_ANSWER_LENGTH = 120
  # Models may still echo source indexes in prose; citations belong in structured metadata.
  BARE_CITATION_INDEX_PATTERN = /(?<![\w\[])\[\s*\d+(?:\s*,\s*\d+)*\s*\](?![\w(])/
  FALLBACK_STOP_WORDS = %w[about also been does from have here into just like more most only page some such than that
                           their them then there they this what when where which will with your].freeze
  # Sources are page-title links, never numbers after each part: customers cannot tell what "[1]" means.
  # The chat widget draws them under the bubble from this content attribute; other channels get them as text lines.
  SOURCES_ATTRIBUTE_KEY = 'captain_sources'.freeze
  # A first sentence this short that opens with a greeting word is a greeting, not part of the answer.
  MAX_GREETING_WORDS = 8
  GREETING_START = /\A(?:hi|hello|hey|welcome|greetings|good\s(?:morning|afternoon|evening)|thanks\sfor\sreaching\sout|hola|buenos\sd[ií]as|
                     bonjour|salut|hallo|guten\stag|ciao|buongiorno|ol[áa]|oi|hej)\b/x
  # Greeting words count as the same word, so "Hi there!" repeats the welcome "Hello and welcome!".
  GREETING_WORDS = %w[hi hello hey welcome greetings hola bonjour salut hallo ciao buongiorno olá ola oi hej].freeze
  SENTENCE_BREAK = /\A[ \t]*(?:[.,!?;:…\n]|\p{Extended_Pictographic}|\z)/
  LEADING_FILLER = /\A(?:[\s.,!?;:¡¿…–—-]|\p{Extended_Pictographic}|\u{FE0F})+/

  # index_offset: how far the model's part indexes (separate_parts) moved: +1 for the prepended welcome, -1 for a dropped part.
  # welcome_guard: 'dropped' or 'stripped' when a repeated welcome was removed from the model's first part.
  attr_reader :parts, :index_offset, :welcome_guard

  def self.from_response(response)
    return new([{ text: response.to_s, citation_indexes: [] }]) unless response.is_a?(Hash)

    response = response.with_indifferent_access
    return new([{ text: response[:response], citation_indexes: [] }]) unless response.key?(:response_parts)
    return new(response[:response_parts]) if response[:welcome].blank?

    # The AI welcome of a first reply opens the answer bubble.
    with_welcome(response[:welcome], new(response[:response_parts]).parts)
  end

  # The model may still open its answer with the welcome or another greeting; never send the welcome twice. If nothing
  # of the answer would remain, the parts stay as the model wrote them.
  def self.with_welcome(welcome, model_parts)
    first, *rest = model_parts
    text = without_repeated_welcome(first['text'], welcome) if first
    kept = text.present? ? [first.merge('text' => text), *rest] : citations_moved(first, rest) unless text.nil?
    welcome_part = { 'text' => welcome, 'citation_indexes' => [] }
    return new([welcome_part, *model_parts], index_offset: 1) if kept.blank?

    dropped = kept.size < model_parts.size
    new([welcome_part, *kept], index_offset: dropped ? 0 : 1, welcome_guard: dropped ? 'dropped' : 'stripped')
  end

  # A dropped part's citations move to the next part.
  def self.citations_moved(dropped, rest)
    return [] if rest.empty?

    [rest.first.merge('citation_indexes' => (dropped['citation_indexes'] + rest.first['citation_indexes']).uniq), *rest.drop(1)]
  end

  # The text without the repeated welcome (blank when it is only the welcome), or nil when it doesn't repeat it.
  def self.without_repeated_welcome(text, welcome)
    welcome_words = words(welcome)
    return if welcome_words.empty?
    return '' if words(text) == welcome_words

    after_welcome = welcome_prefix_remainder(text, welcome_words)
    return after_welcome.sub(LEADING_FILLER, '') if after_welcome

    sentence, remainder = text.split(/(?<=[.!?])\s+|\n+/, 2)
    remainder.to_s.sub(LEADING_FILLER, '') if greeting_sentence?(sentence, welcome)
  end

  # The text after the welcome when the text opens with the whole welcome sentence ("Hello and welcome! To clear…"),
  # not when the welcome's words run on into the answer ("Hello and welcome to…").
  def self.welcome_prefix_remainder(text, welcome_words)
    return unless words(text).first(welcome_words.size) == welcome_words

    remainder = text[text.to_enum(:scan, /[[:alnum:]]+/).map { Regexp.last_match.end(0) }[welcome_words.size - 1]..]
    remainder if remainder.match?(SENTENCE_BREAK)
  end

  def self.greeting_sentence?(sentence, welcome)
    sentence_words = greeting_words(sentence).uniq
    return false if sentence_words.size > MAX_GREETING_WORDS || !words(sentence).join(' ').match?(GREETING_START)

    (sentence_words & greeting_words(welcome)).size * 2 >= sentence_words.size
  end

  # Lowercase words without punctuation or emoji.
  def self.words(text)
    text.to_s.downcase.scan(/[[:alnum:]]+/)
  end

  # Words with every greeting word as "hello".
  def self.greeting_words(text)
    words(text).map { |word| GREETING_WORDS.include?(word) ? 'hello' : word }
  end

  private_class_method :with_welcome, :citations_moved, :without_repeated_welcome, :welcome_prefix_remainder, :greeting_sentence?, :words,
                       :greeting_words

  def initialize(response_parts, index_offset: 0, welcome_guard: nil)
    @parts = Array(response_parts).filter_map { |part| normalize_part(part) }
    @index_offset = index_offset
    @welcome_guard = welcome_guard
  end

  # Called once where the reply is composed, so one guarded reply logs once.
  def log_welcome_guard
    Rails.logger.info "[Captain][ReplyGuard] rule=duplicate_welcome action=#{welcome_guard}" if welcome_guard
    self
  end

  def plain_text
    parts.pluck('text').join("\n\n")
  end

  # The model sometimes cites nothing for an answer it clearly took from one page. Cite the page whose title shares
  # the most distinctive words with the answer (at least FALLBACK_MIN_SHARED_WORDS), so its link is not lost.
  def with_fallback_citation(citation_titles:, ignored_words: [])
    return self if citation_titles.blank? || parts.any? { |part| part['citation_indexes'].present? }

    index = fallback_citation_index(citation_titles, ignored_words)
    return self unless index

    cited = parts.map(&:dup)
    cited.last['citation_indexes'] = [index]
    self.class.new(cited, index_offset: index_offset)
  end

  # Reference visibility never adds or removes useful links from the answer itself.
  def self.sources_format(conversation, sources_card: true)
    return :none unless sources_card

    case conversation&.inbox&.channel_type
    when nil, 'Channel::WebWidget' then :structured
    when 'Channel::Email' then :markdown
    else :plain
    end
  end

  def customer_message_content(citation_urls: {}, citation_titles: {}, sources_format: :markdown)
    body = plain_text
    return body if sources_format.in?(%i[structured none])

    links = sources(citation_urls: citation_urls, citation_titles: citation_titles).reject { |link| body.include?(link['url']) }
    return body if links.empty?

    "#{body}\n\n#{links.map { |link| source_line(link, sources_format) }.join("\n")}"
  end

  # Evidence includes pages linked in the answer, so enabling both controls still shows the reference card.
  def sources(citation_urls: {}, citation_titles: {})
    cited_links(citation_urls, citation_titles).first(MAX_SOURCE_LINKS).map { |url, title| { 'title' => title, 'url' => url } }
  end

  def to_a
    parts
  end

  private

  # The arrow keeps the lines readable in every reply language.
  def source_line(link, sources_format)
    return "→ #{link['title']}: #{link['url']}" if sources_format == :plain

    "→ [#{link['title'].tr('[]', '()')}](#{link['url'].gsub('(', '%28').gsub(')', '%29')})"
  end

  def cited_links(citation_urls, citation_titles)
    parts.flat_map { |part| part['citation_indexes'] }.each_with_object({}) do |index, links|
      url = citation_urls[index]
      next if url.blank? || links.key?(url)

      links[url] = citation_titles[index].presence || title_from_url(url)
    end
  end

  def fallback_citation_index(citation_titles, ignored_words)
    text = plain_text
    return if text.length < FALLBACK_MIN_ANSWER_LENGTH

    answer_words = distinctive_words(text, ignored_words)
    best_index, best_count = citation_titles.filter_map do |index, title|
      [index, (distinctive_words(title.to_s.split(/\s[|·–-]\s/).first, ignored_words) & answer_words).size]
    end.max_by(&:last)
    best_index if best_count.to_i >= FALLBACK_MIN_SHARED_WORDS
  end

  # Words of four or more letters, singular, so "purchases" in the answer matches "purchase" in a title.
  def distinctive_words(text, ignored_words)
    words = text.to_s.downcase.scan(/[[:alnum:]]{4,}/).map { |word| word.delete_suffix('s') }
    words.uniq - FALLBACK_STOP_WORDS - ignored_words.map { |word| word.to_s.downcase.delete_suffix('s') }
  end

  def title_from_url(url)
    uri = URI.parse(url)
    segment = uri.path.to_s.split('/').compact_blank.last
    segment ? segment.sub(/\A\d+-/, '').tr('-_', '  ').squish.capitalize : uri.host.to_s.delete_prefix('www.')
  rescue URI::InvalidURIError
    url
  end

  def normalize_part(part)
    return unless part.is_a?(Hash)

    part = part.with_indifferent_access
    return unless part[:text].is_a?(String)

    text = part[:text].gsub(BARE_CITATION_INDEX_PATTERN, '').gsub(/[ \t]+([.,!?;:])/, '\\1').strip
    return if text.blank?

    {
      'text' => text,
      'citation_indexes' => Array(part[:citation_indexes]).select do |citation_index|
        citation_index.is_a?(Integer) && citation_index.positive?
      end.uniq
    }
  end
end

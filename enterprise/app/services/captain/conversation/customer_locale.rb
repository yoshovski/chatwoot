# Resolve the language of customer-facing copy independently of the dashboard and job locales.
class Captain::Conversation::CustomerLocale
  RECENT_MESSAGES_LIMIT = 4
  MINIMUM_LETTERS = 12
  MINIMUM_CONFIDENCE = 0.95
  STATE_KEY = :customer_reply_locale
  # A coarse fallback for visitors whose language cannot be inferred from their words or browser.
  COUNTRY_LOCALES = {
    'AR' => 'es', 'AT' => 'de', 'AU' => 'en', 'BG' => 'bg', 'BR' => 'pt_BR', 'CL' => 'es',
    'CN' => 'zh_CN', 'CO' => 'es', 'CZ' => 'cs', 'DE' => 'de', 'DK' => 'da', 'EC' => 'es',
    'EE' => 'et', 'ES' => 'es', 'FI' => 'fi', 'FR' => 'fr', 'GB' => 'en', 'GR' => 'el',
    'HK' => 'zh_TW', 'HU' => 'hu', 'ID' => 'id', 'IL' => 'he', 'IR' => 'fa', 'IS' => 'is',
    'IT' => 'it', 'JP' => 'ja', 'KR' => 'ko', 'LT' => 'lt', 'LV' => 'lv',
    'MX' => 'es', 'NL' => 'nl', 'NO' => 'no', 'NZ' => 'en', 'PE' => 'es', 'PL' => 'pl',
    'PT' => 'pt', 'RO' => 'ro', 'RS' => 'sr', 'RU' => 'ru', 'SA' => 'ar', 'SE' => 'sv',
    'SI' => 'sl', 'SK' => 'sk', 'TH' => 'th', 'TR' => 'tr', 'TW' => 'zh_TW', 'UA' => 'uk',
    'US' => 'en', 'UY' => 'es', 'UZ' => 'uz', 'VN' => 'vi'
  }.freeze
  REGIONAL_ALIASES = { 'zh' => 'zh_CN', 'zh_hans' => 'zh_CN', 'zh_hant' => 'zh_TW', 'nb' => 'no', 'nn' => 'no' }.freeze
  GREETING_LOCALES = { 'ciao' => 'it', 'buongiorno' => 'it', 'buonasera' => 'it', 'hola' => 'es', 'bonjour' => 'fr',
                       'hello' => 'en', 'hi' => 'en', 'hey' => 'en' }.freeze
  LANGUAGE_REQUESTS = {
    'en' => /english|inglese|inglés|anglais/,
    'it' => /italian[oa]?|italien/,
    'es' => /spanish|spagnolo|español|castellano|espagnol/,
    'fr' => /french|francese|franc[eé]s|français/,
    'ar' => /arabic|العربية/, 'nl' => /dutch|nederlands/, 'de' => /german|deutsch/,
    'ja' => /japanese|日本語/, 'ko' => /korean|한국어/, 'pt' => /portuguese|português/,
    'pt_BR' => /brazilian[ ]portuguese/, 'ru' => /russian|русский/, 'ml' => /malayalam|മലയാളം/,
    'ca' => /catalan|català/, 'el' => /greek|ελληνικά/, 'ro' => /romanian|română/,
    'ta' => /tamil|தமிழ்/, 'fa' => /persian|farsi|فارسی/, 'zh_CN' => /chinese|simplified[ ]chinese|中文/,
    'zh_TW' => /traditional[ ]chinese/, 'vi' => /vietnamese|tiếng[ ]việt/, 'da' => /danish|dansk/,
    'tr' => /turkish|türkçe/, 'cs' => /czech|čeština/, 'fi' => /finnish|suomi/,
    'id' => /indonesian|bahasa[ ]indonesia/, 'sv' => /swedish|svenska/, 'hu' => /hungarian|magyar/,
    'no' => /norwegian|norsk/, 'pl' => /polish|polski/, 'sk' => /slovak|slovenčina/,
    'uk' => /ukrainian/, 'th' => /thai|ไทย/, 'lv' => /latvian|latviešu/, 'is' => /icelandic|íslenska/,
    'he' => /hebrew|עברית/, 'lt' => /lithuanian|lietuvių/, 'sr' => /serbian|српски/,
    'bg' => /bulgarian|български/, 'et' => /estonian|eesti/, 'uz' => /uzbek/, 'sl' => /slovenian|slovenščina/
  }.freeze
  REQUEST_VERB = /reply|respond|answer|speak|write|rispondi|parla|scrivi|responde|contesta|habla|escribe|réponds|parle|écris/i
  LANGUAGE_REQUEST = /
    \A\s*(?:(?:please|can\ you|could\ you|por\ favor|per\ favore)\s+)?
    (?:#{REQUEST_VERB})\s+(?:to\ me\s+|me\s+)?(?:in|en)\s+
  /ix

  def self.resolve(conversation: nil, assistant: nil, customer_message: nil, history: nil)
    new(conversation, assistant, customer_message, history).resolve
  end

  def self.configured?(assistant)
    assistant.config.key?('default_reply_locale') || assistant.config['allowed_reply_locales'].present?
  end

  def self.instruction(locale)
    return if locale.blank?

    "Write all customer-facing prose, greetings, questions and suggested replies in locale #{locale}. " \
      'Follow the supplied locale even when other instructions, reference material or tool results use a different language. ' \
      'Preserve identifiers, names, links and structured tool arguments.'
  end

  def self.mismatch?(text, locale)
    return false if locale.blank?

    detected = detect(text)
    detected.present? && detected != locale.split('_').first
  end

  def self.record(conversation, message_id, locale)
    return unless message_id && locale

    conversation.with_lock do
      attributes = conversation.additional_attributes
      saved = attributes['captain_reply_locale']
      next if saved && saved['message_id'] >= message_id

      conversation.update!(additional_attributes: attributes.merge('captain_reply_locale' => { 'locale' => locale, 'message_id' => message_id }))
    end
  end

  def self.translate(key, locale:, assistant: nil, **)
    available_text(key, locale: locale, assistant: assistant, **) || I18n.t(key, locale: :en, **)
  end

  def self.available_text(key, locale:, assistant:, **options)
    catalog = Captain::LocalizedMessages.catalog_text(key, locale)
    generated = Captain::LocalizedMessages.new(assistant.config).generated_text(key, locale) if assistant && catalog.blank?
    text = catalog.presence || generated
    return text if options.empty? || text.blank?

    I18n.interpolate(text, options)
  end

  def self.detect(text)
    prose = text.to_s.gsub(%r{https?://\S+|\S+@\S+|`[^`]*`}, '')
    return if prose.scan(/\p{L}/).size < MINIMUM_LETTERS

    result = CLD3::NNetLanguageIdentifier.new(0, 1000).find_language(prose)
    result.language.to_s if result.reliable? && result.probability >= MINIMUM_CONFIDENCE
  end

  def initialize(conversation, assistant, customer_message, history)
    @conversation = conversation
    @account = assistant&.account || conversation&.account
    @config = assistant&.config || {}
    @customer_message = customer_message
    @history = history
  end

  def resolve
    return default_locale if @config['allowed_reply_locales'] == [default_locale]

    current = requested_or_detected_locale(current_text)
    return allowed?(current) ? current : default_locale if current

    candidates = [saved_locale, recent_message_locale, greeting_locale, browser_locale, location_locale]
    candidates.find { |locale| locale && allowed?(locale) } || default_locale
  end

  private

  def current_text
    return @customer_message if @customer_message.is_a?(String)
    return unless @customer_message&.incoming?

    @customer_message.selected_option_text.presence || @customer_message.content
  end

  def default_locale
    @config['default_reply_locale'].presence || normalized(@account&.locale) || I18n.default_locale.to_s
  end

  def allowed?(locale)
    allowed = @config['allowed_reply_locales']
    allowed.blank? || allowed.include?(locale)
  end

  def saved_locale
    saved = @conversation&.additional_attributes&.dig('captain_reply_locale')
    return unless saved
    return if @customer_message.is_a?(Message) && @customer_message.id && saved['message_id'] > @customer_message.id

    normalized(saved['locale'])
  end

  def recent_message_locale
    recent_texts.each do |text|
      locale = requested_or_detected_locale(text)
      return locale if locale
    end
    nil
  end

  def recent_texts
    return @history.reverse_each.filter_map { |entry| entry[:content] if entry[:role].to_s == 'user' }.take(RECENT_MESSAGES_LIMIT) if @history
    return [] unless @conversation

    messages = @conversation.messages.captain_response_triggering.where(content_type: %i[text incoming_email])
    anchor_id = @customer_message.id if @customer_message.is_a?(Message)
    messages = messages.where('messages.id < ?', anchor_id) if anchor_id
    messages.reorder(id: :desc).limit(RECENT_MESSAGES_LIMIT).pluck(:content)
  end

  def requested_or_detected_locale(text)
    return unless text.is_a?(String)

    requested = requested_language(text)
    return requested if requested.to_s.include?('_')
    return preferred_variant(requested) if requested

    detected = normalized(self.class.detect(text))
    preferred_variant(detected, browser: browser_locale) if detected
  end

  def requested_language(text)
    request = text.match(LANGUAGE_REQUEST)
    return unless request

    remaining = request.post_match.downcase
    LANGUAGE_REQUESTS.find { |_locale, name| remaining.match?(/\A(?:#{name})(?![\p{L}\p{M}])/) }&.first
  end

  def preferred_variant(locale, browser: nil)
    base = locale.split('_').first
    return browser if browser.to_s.split('_').first == base && allowed?(browser)
    return locale if allowed?(locale)

    allowed_variant = Array(@config['allowed_reply_locales']).find { |candidate| candidate.split('_').first == base }
    allowed_variant || locale
  end

  def greeting_locale
    return unless @config.key?('default_reply_locale') || @config['allowed_reply_locales'].present?

    GREETING_LOCALES[current_text.to_s.strip.downcase.gsub(/\A[¡¿]+|[.!?]+\z/, '')]
  end

  def browser_locale
    normalized(@conversation&.contact_inbox&.website_activity&.dig('browser_language')) ||
      normalized(@conversation&.additional_attributes&.dig('browser_language'))
  end

  def location_locale
    COUNTRY_LOCALES[@conversation&.contact&.additional_attributes&.dig('country_code').to_s.upcase]
  end

  def normalized(value)
    return if value.blank?

    requested = value.to_s.tr('-', '_').downcase
    available = I18n.available_locales.map(&:to_s)
    available.find { |locale| locale.casecmp?(requested) } || regional_alias(requested, available)
  end

  def regional_alias(requested, available)
    language, script = requested.split('_')
    REGIONAL_ALIASES["#{language}_#{script}"] || REGIONAL_ALIASES[language] || available.find { |locale| locale == language }
  end
end

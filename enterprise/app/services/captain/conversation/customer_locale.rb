# Resolve the language of customer-facing copy independently of the dashboard and job locales.
class Captain::Conversation::CustomerLocale
  RECENT_MESSAGES_LIMIT = 4
  MINIMUM_LETTERS = 12
  MINIMUM_CONFIDENCE = 0.95
  STATE_KEY = :customer_reply_locale
  COUNTRY_LOCALES = { 'IT' => 'it', 'ES' => 'es', 'FR' => 'fr' }.freeze
  LANGUAGE_REQUESTS = {
    'en' => /english|inglese|inglés|anglais/,
    'it' => /italian[oa]?|italien/,
    'es' => /spanish|spagnolo|español|castellano|espagnol/,
    'fr' => /french|francese|franc[eé]s|français/
  }.freeze
  REQUEST_VERB = /reply|respond|answer|speak|write|rispondi|parla|scrivi|responde|contesta|habla|escribe|réponds|parle|écris/i
  LANGUAGE_REQUEST = /
    \A\s*(?:(?:please|can\ you|could\ you|por\ favor|per\ favore)\s+)?
    (?:#{REQUEST_VERB})\s+(?:to\ me\s+|me\s+)?(?:in|en)\s+(\p{L}+)
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

    candidates = [saved_locale, recent_message_locale, browser_locale, location_locale]
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

    request = text.match(LANGUAGE_REQUEST)
    requested = LANGUAGE_REQUESTS.find { |_locale, name| request && request[1].downcase.match?(/\A(?:#{name})\z/) }&.first
    requested || normalized(self.class.detect(text))
  end

  def browser_locale
    normalized(@conversation&.contact_inbox&.website_activity&.dig('browser_language')) ||
      normalized(@conversation&.additional_attributes&.dig('browser_language'))
  end

  def location_locale
    COUNTRY_LOCALES[@conversation&.contact&.additional_attributes&.dig('country_code')]
  end

  def normalized(value)
    return if value.blank?

    requested = value.to_s.tr('-', '_').downcase
    available = I18n.available_locales.map(&:to_s)
    available.find { |locale| locale.casecmp?(requested) } || available.find { |locale| locale == requested.split('_').first }
  end
end

# frozen_string_literal: true

class Captain::Conversation::ReplyLabels
  MAX_LABELS = 3

  LABEL_ORDER = %w[
    needs-human
    quote-request
    order-issue
    compatibility
    out-of-stock
    product-inquiry
    regulation
    policy
  ].freeze

  DEFAULT_KEYWORDS = {
    'quote-request' => %w[quote bulk discount].freeze,
    'order-issue' => ['my order', 'order number', 'tracking', 'damaged', 'refund', 'return'].freeze,
    'compatibility' => ['compatible', 'work with', 'fit', 'difference between'].freeze,
    'out-of-stock' => ['out of stock', 'sold out', 'back order'].freeze,
    'product-inquiry' => ['price', 'cost', 'buy', 'in stock', 'looking for', 'recommend'].freeze,
    'regulation' => [].freeze,
    'policy' => ['ship', 'shipping', 'delivery', 'warranty', 'repair', 'payment', 'lead time'].freeze
  }.freeze

  attr_reader :assistant, :customer_message, :answer, :products_shown, :handed_off

  def initialize(assistant:, customer_message:, answer:, products_shown: false, handed_off: false)
    @assistant = assistant
    @customer_message = customer_message.is_a?(Message) ? customer_message.content : customer_message.to_s
    @answer = answer.to_s
    @products_shown = products_shown == true
    @handed_off = handed_off == true
  end

  def labels
    keywords = merged_keywords
    LABEL_ORDER.select { |label| label_applies?(label, keywords) }.take(MAX_LABELS)
  end

  private

  def label_applies?(label, keywords)
    case label
    when 'needs-human'
      handed_off
    when 'out-of-stock'
      match_keywords?(answer, keywords[label])
    when 'product-inquiry'
      products_shown || match_keywords?(customer_message, keywords[label])
    else
      match_keywords?(customer_message, keywords[label])
    end
  end

  def merged_keywords
    custom = custom_reply_label_keywords
    return DEFAULT_KEYWORDS if custom.blank?

    DEFAULT_KEYWORDS.merge(custom.transform_keys(&:to_s))
  end

  def custom_reply_label_keywords
    config = assistant&.config
    return if config.blank?

    config['reply_label_keywords'] || config[:reply_label_keywords]
  end

  def match_keywords?(text, keyword_list)
    return false if text.blank? || keyword_list.blank?

    keyword_list.any? do |kw|
      phrase = kw.to_s.strip
      next false if phrase.blank?

      text.match?(/\b#{Regexp.escape(phrase)}\b/i)
    end
  end
end

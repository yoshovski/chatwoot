# One piece of a reply plan. kind is greeting, answer, question, order_card, product_cards, form or confirmation.
# parts are the prose parts of a greeting, answer or question bubble (nil for cards and forms); media: true lets
# the bubble carry the knowledge videos and screenshots. attach: :next merges the segment into the next bubble.
Captain::Reply::Segment = Data.define(:kind, :text, :parts, :content_type, :content_attributes, :additional_attributes, :attach, :media) do
  def initialize(kind:, media: false, **attributes)
    super(kind: kind, media: media, text: nil, parts: nil, content_type: nil, content_attributes: nil, additional_attributes: nil, attach: nil,
          **attributes)
  end

  # A segment built from a finished message payload (cards, forms, confirmation cards).
  def self.from_payload(kind, payload)
    new(kind: kind, text: payload[:content], content_type: payload[:content_type], content_attributes: payload[:content_attributes],
        additional_attributes: payload[:additional_attributes])
  end

  def prose? = !parts.nil?

  def buttons? = content_attributes&.key?(:items).present?

  def payload(parts: self.parts)
    attributes = additional_attributes
    attributes = attributes.to_h.merge(Captain::Assistant::ResponseParts::MESSAGE_ATTRIBUTE_KEY => parts.map(&:to_response_part)) if parts
    { content: text, content_type: content_type, content_attributes: content_attributes, additional_attributes: attributes }
      .compact.reverse_merge(content: nil)
  end
end

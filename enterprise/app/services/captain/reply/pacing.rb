# Stamps the payloads of one widget reply so the widget reveals them like a person typing (Captain::Behaviour has the
# timings). captain_reply_id is shared by the bubbles of the reply; captain_reveal_offset_ms counts from the arrival
# of its first bubble in the widget. Other channels and the dashboard show every bubble at once.
module Captain::Reply::Pacing
  REPLY_ID_KEY = 'captain_reply_id'.freeze
  OFFSET_KEY = 'captain_reveal_offset_ms'.freeze
  TEXT_CONTENT_TYPES = [nil, 'text'].freeze

  def self.stamp(payloads, responding_to:, now: Time.current)
    reply_id = SecureRandom.uuid
    offset = first_offset(responding_to, now)
    payloads.each_with_index.map do |payload, index|
      offset += Captain::Behaviour.bubble_pause_ms(payload[:content]) if index.positive? && text?(payload)
      attributes = payload[:additional_attributes].to_h.merge(REPLY_ID_KEY => reply_id, OFFSET_KEY => offset)
      payload.merge(additional_attributes: attributes)
    end
  end

  # The rest of the minimum typing time, counted from the visitor's message (generation usually took longer).
  def self.first_offset(responding_to, now)
    return 0 unless responding_to

    elapsed_ms = ((now - responding_to.created_at) * 1000).round
    [Captain::Behaviour::REPLY_MIN_TYPING_MS - elapsed_ms, 0].max
  end

  def self.text?(payload) = TEXT_CONTENT_TYPES.include?(payload[:content_type])

  private_class_method :first_offset, :text?
end

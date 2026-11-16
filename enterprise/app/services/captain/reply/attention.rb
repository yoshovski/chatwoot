# Stamps a widget reply with what it asks of the visitor, so the widget knows whether to point at a waiting
# question or, once the answer is complete, offer "anything else?". Buttons alone never mean an answer is required;
# a reply that already offers a next step needs no extra offer; anything unclear stays quiet.
module Captain::Reply::Attention
  INTENT_KEY = 'captain_attention_intent'.freeze
  FOLLOW_UP_INTENTS = { 'next_step' => 'offered', 'clarification' => 'awaiting_answer', 'qualification' => 'awaiting_answer' }.freeze

  def self.stamp(payloads, response:, assistant:, suppressed: false)
    intent = suppressed ? 'none' : intent_for(payloads, response)
    delays = {
      'question' => Captain::Behaviour.widget_check_in_awaiting_seconds(assistant) * 1000,
      'check_in' => Captain::Behaviour.widget_check_in_completed_seconds(assistant) * 1000
    }
    payloads.each_with_index.map do |payload, index|
      attributes = { INTENT_KEY => intent, 'captain_attention_delays' => delays, 'captain_reply_final' => index == payloads.size - 1 }
      payload.merge(additional_attributes: payload[:additional_attributes].to_h.merge(attributes))
    end
  end

  def self.intent_for(payloads, response)
    return 'none' if payloads.any? { |payload| payload[:content_type] == 'form' }

    follow_up = response['follow_up'] if response.is_a?(Hash)
    return FOLLOW_UP_INTENTS.fetch(follow_up['kind'], 'none') if follow_up.is_a?(Hash)

    segment_intent(payloads)
  end

  def self.segment_intent(payloads)
    kinds = payloads.flat_map { |payload| Array(payload.dig(:additional_attributes, Captain::Reply::Plan::SEGMENT_KINDS_KEY)).map(&:to_s) }
    return 'none' if kinds.include?('confirmation')
    return 'awaiting_answer' if kinds.include?('question')
    return 'none' if payloads.any? { |payload| payload[:content].to_s.rstrip.end_with?('?') }

    'answer_complete'
  end

  private_class_method :intent_for, :segment_intent
end

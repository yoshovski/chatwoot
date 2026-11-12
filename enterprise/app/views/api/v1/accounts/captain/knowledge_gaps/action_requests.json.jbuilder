json.payload do
  json.array! @action_requests do |request|
    json.intent request[:intent]
    json.conversations_count request[:gaps].sum(&:occurrences_count)
    json.last_seen_at request[:gaps].map(&:last_seen_at).max.to_i
    json.gap_ids request[:gaps].map(&:id)
    json.examples request[:examples]
  end
end

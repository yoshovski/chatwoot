json.payload do
  json.array! @topics do |group|
    json.topic group[:topic]
    json.conversations_count group[:gaps].sum(&:occurrences_count)
    json.gaps do
      json.array! group[:gaps] do |gap|
        json.partial! 'api/v1/models/captain/knowledge_gap', formats: [:json], resource: gap
        json.examples @examples.fetch(gap.id, [])
      end
    end
  end
end

json.partial! 'api/v1/models/captain/knowledge_gap', formats: [:json], resource: @gap
json.occurrences do
  json.array! @occurrences do |occurrence|
    json.id occurrence.id
    json.reason occurrence.reason
    json.created_at occurrence.created_at.to_i
    json.conversation do
      json.id occurrence.conversation.id
      json.display_id occurrence.conversation.display_id
    end
  end
end

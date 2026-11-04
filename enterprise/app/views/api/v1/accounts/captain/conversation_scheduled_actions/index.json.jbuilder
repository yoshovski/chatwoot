json.payload @scheduled_actions do |action|
  json.id action.id
  json.kind action.kind
  json.due_at action.due_at.to_i
  json.created_at action.created_at.to_i
end

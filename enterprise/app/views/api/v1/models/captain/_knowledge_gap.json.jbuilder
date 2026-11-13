json.id resource.id
json.account_id resource.account_id
json.question resource.question
json.status resource.status
json.kind resource.kind
json.topic resource.topic
json.language resource.language
json.intent resource.intent
json.draft_answer resource.draft_answer
json.occurrences_count resource.occurrences_count
json.last_seen_at resource.last_seen_at.to_i
json.created_at resource.created_at.to_i
json.response_id resource.response_id
json.assistant do
  json.partial! 'api/v1/models/captain/assistant', formats: [:json], resource: resource.assistant
end

if conversation.ai_assignee.is_a?(Captain::Assistant)
  json.assignee do
    json.partial! 'api/v1/models/captain/assistant_slim', formats: [:json], resource: conversation.ai_assignee
  end
  json.assignee_type 'Captain::Assistant'
end

captain_waiting_assistant = conversation.captain_waiting_assistant
if captain_waiting_assistant
  json.captain_waiting do
    json.partial! 'api/v1/models/captain/assistant_slim', formats: [:json], resource: captain_waiting_assistant
  end
end

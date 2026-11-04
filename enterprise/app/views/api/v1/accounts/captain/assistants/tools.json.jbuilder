json.array! @tools do |tool|
  json.id tool[:id]
  json.title tool[:title]
  json.description tool[:description]
  json.icon tool[:icon]
  json.emoji tool[:emoji]
  json.built_in_action tool[:built_in_action] if tool[:built_in_action]
  json.custom true if tool[:custom]
  json.mcp true if tool[:mcp]
  json.fixed_params tool[:fixed_params] if tool[:fixed_params]
end

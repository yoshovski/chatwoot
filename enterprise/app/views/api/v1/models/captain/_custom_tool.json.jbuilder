json.id custom_tool.id
json.slug custom_tool.slug
json.title custom_tool.title
json.description custom_tool.description
json.endpoint_url custom_tool.endpoint_url
json.http_method custom_tool.http_method
json.request_template custom_tool.request_template
json.response_template custom_tool.response_template
json.auth_type custom_tool.auth_type
json.auth_config custom_tool.public_auth_config if Current.user&.administrator?
json.auth_configured custom_tool.auth_configured?
json.param_schema custom_tool.param_schema
# Like auth_config, a step's auth username and header name are for administrators only.
json.steps(custom_tool.public_steps.map do |step|
  step['auth'].present? && !Current.user&.administrator? ? step.merge('auth' => step['auth'].slice('type', 'same_as')) : step
end)
json.outputs custom_tool.outputs
json.execution_mode custom_tool.execution_mode
json.messages custom_tool.messages
json.enabled custom_tool.enabled
json.account_id custom_tool.account_id
json.created_at custom_tool.created_at.to_i
json.updated_at custom_tool.updated_at.to_i

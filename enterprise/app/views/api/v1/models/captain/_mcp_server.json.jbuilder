json.id mcp_server.id
json.name mcp_server.name
json.endpoint_url mcp_server.endpoint_url
json.auth_type mcp_server.auth_type
json.auth_header_name mcp_server.auth_header_name
json.has_auth_token mcp_server.auth_token.present?
json.status mcp_server.status
json.last_error mcp_server.last_error
json.synced_at mcp_server.synced_at&.to_i
json.tools mcp_server.tools do |tool|
  json.extract! tool, 'id', 'name', 'title', 'description', 'enabled'
end

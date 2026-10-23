# Minimal MCP client for the Streamable HTTP transport: JSON-RPC over HTTPS POST, with JSON or SSE replies.
# Requests go through SafeFetch, so a server URL can never reach private networks. Each operation opens
# its own short session (initialize, then the request), which keeps the client stateless across workers.
class Captain::Mcp::Client
  class Error < StandardError; end

  PROTOCOL_VERSION = '2025-06-18'.freeze
  MAX_RESPONSE_SIZE = 1.megabyte
  MAX_TOOL_PAGES = 5
  READ_TIMEOUT = 20

  def initialize(server)
    @server = server
  end

  def list_tools
    with_session do
      tools = []
      cursor = nil
      MAX_TOOL_PAGES.times do
        result = request('tools/list', cursor ? { cursor: cursor } : {})
        tools.concat(Array(result['tools']))
        cursor = result['nextCursor']
        break if cursor.blank?
      end
      tools
    end
  end

  # Returns the tool's text content. A tool-level error comes back as text, so the agent can explain it.
  def call_tool(name, arguments)
    with_session do
      result = request('tools/call', { name: name, arguments: arguments })
      text = Array(result['content']).filter_map { |item| item['text'] if item['type'] == 'text' }.join("\n")
      text = result['structuredContent'].to_json if text.blank? && result['structuredContent']
      result['isError'] ? "ERROR: #{text}" : text
    end
  end

  private

  def with_session
    @session_id = nil
    @next_id = 0
    request('initialize', { protocolVersion: PROTOCOL_VERSION, capabilities: {},
                            clientInfo: { name: 'captain', version: '1.0' } })
    post({ jsonrpc: '2.0', method: 'notifications/initialized' })
    yield
  end

  def request(method, params)
    id = (@next_id += 1)
    body, headers = post({ jsonrpc: '2.0', id: id, method: method, params: params })
    @session_id ||= headers['mcp-session-id']
    message = parse_messages(body, headers['content-type']).find { |item| item['id'] == id }
    raise Error, "No response to #{method}" unless message
    raise Error, message.dig('error', 'message').presence || "#{method} failed" if message['error']

    message.fetch('result')
  end

  def post(payload)
    body = +''
    headers = {}
    SafeFetch.fetch(@server.endpoint_url, method: :post, body: payload.to_json, headers: request_headers,
                                          sensitive_headers: auth_headers.keys, max_bytes: MAX_RESPONSE_SIZE,
                                          read_timeout: READ_TIMEOUT, validate_content_type: false) do |result|
      body = result.tempfile.read
      headers = result.headers
    end
    [body, headers]
  rescue SafeFetch::Error => e
    raise Error, e.message
  end

  def request_headers
    headers = { 'Content-Type' => 'application/json', 'Accept' => 'application/json, text/event-stream',
                'MCP-Protocol-Version' => PROTOCOL_VERSION }
    headers['Mcp-Session-Id'] = @session_id if @session_id
    headers.merge(auth_headers)
  end

  def auth_headers
    case @server.auth_type
    when 'bearer' then { 'Authorization' => "Bearer #{@server.auth_token}" }
    when 'header' then { @server.auth_header_name => @server.auth_token.to_s }
    else {}
    end
  end

  # A reply is either one JSON object/array or a stream of SSE events whose data lines hold JSON-RPC messages.
  def parse_messages(body, content_type)
    return Array.wrap(JSON.parse(body)) unless content_type.to_s.start_with?('text/event-stream')

    body.split(/\r?\n\r?\n/).filter_map do |event|
      data = event.lines.filter_map { |line| line.delete_prefix('data:').strip if line.start_with?('data:') }.join
      JSON.parse(data) if data.present?
    end
  rescue JSON::ParserError
    raise Error, 'The server returned an invalid response'
  end
end

require 'agents'

# Calls one enabled tool on a remote MCP server, with the server's own input schema.
class Captain::Tools::McpTool < Captain::Tools::BasePublicTool
  # Tool classes need a constant name, or the LLM API receives an empty function name.
  module Generated; end

  def self.build(server, tool, assistant)
    class_name = tool['id'].camelize.gsub(/[^A-Za-z0-9]/, '')
    schema = tool['input_schema'].except('$schema').presence || { 'type' => 'object', 'properties' => {} }
    tool_class = Class.new(self) do
      description tool['description'].presence || tool['title']
      params schema
      define_method(:name) { tool['id'] }
    end
    Generated.send(:remove_const, class_name) if Generated.const_defined?(class_name, false)
    Generated.const_set(class_name, tool_class)
    tool_class.new(assistant, server, tool['name'])
  end

  def initialize(assistant, server, remote_name)
    @server = server
    @remote_name = remote_name
    super(assistant)
  end

  def perform(tool_context, **params)
    Captain::Mcp::Client.new(@server).call_tool(@remote_name, params)
  rescue Captain::Mcp::Client::Error => e
    Rails.logger.warn("[Captain][MCP] server_id=#{@server.id} tool=#{@remote_name} error=#{e.message}")
    failure_result('The connected service did not respond. Try again later.', tool_context.state)
  end
end

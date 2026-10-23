# A remote MCP server whose tools scenarios can use. Tools are listed from the server and each one starts
# disabled: an administrator enables the ones the AI agent may call.
class Captain::McpServer < ApplicationRecord
  class LimitExceededError < StandardError; end

  include Concerns::SafeEndpointValidatable

  self.table_name = 'captain_mcp_servers'

  MAX_PER_ACCOUNT = 10
  # OpenAI and Gemini accept function names up to 64 characters from this alphabet.
  MAX_TOOL_ID_LENGTH = 64
  STATUSES = %w[pending connected failed].freeze

  belongs_to :account

  encrypts :auth_token if Chatwoot.encryption_configured?

  enum :auth_type, %w[none bearer header].index_by(&:itself), default: :none, validate: true, prefix: :auth

  validates :name, presence: true, length: { maximum: 100 }
  validates :endpoint_url, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :auth_token, presence: true, unless: :auth_none?
  validates :auth_header_name, presence: true, format: { with: /\A[A-Za-z0-9-]+\z/ }, if: :auth_header?
  before_create :ensure_within_limit

  # Lists the server's tools, keeping the enabled choice of tools that still exist.
  def sync_tools!
    enabled = tools.select { |tool| tool['enabled'] }.pluck('name').to_set
    listed = Captain::Mcp::Client.new(self).list_tools.map { |tool| stored_tool(tool, enabled.include?(tool['name'])) }
    update!(tools: listed, status: 'connected', last_error: nil, synced_at: Time.current)
  rescue Captain::Mcp::Client::Error => e
    update!(status: 'failed', last_error: e.message.truncate(500), synced_at: Time.current)
  end

  def enabled_tools = tools.select { |tool| tool['enabled'] }

  def tool_metadata
    enabled_tools.map { |tool| { id: tool['id'], title: tool['title'], description: tool['description'], emoji: '🧩', mcp: true } }
  end

  def agent_tool(tool_id, assistant)
    tool = enabled_tools.find { |item| item['id'] == tool_id }
    Captain::Tools::McpTool.build(self, tool, assistant) if tool
  end

  private

  def stored_tool(tool, enabled)
    { 'id' => tool_id(tool['name']), 'name' => tool['name'], 'title' => tool['title'].presence || tool['name'],
      'description' => tool['description'].to_s.truncate(1000), 'input_schema' => tool['inputSchema'] || {}, 'enabled' => enabled }
  end

  def tool_id(name)
    "mcp#{id}_#{name.to_s.gsub(/[^a-zA-Z0-9_-]/, '_')}".first(MAX_TOOL_ID_LENGTH)
  end

  def ensure_within_limit
    Account.lock.find(account_id)
    return if account.captain_mcp_servers.count < MAX_PER_ACCOUNT

    raise LimitExceededError, I18n.t('captain.mcp_server.limit_exceeded', limit: MAX_PER_ACCOUNT)
  end
end

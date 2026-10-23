class Api::V1::Accounts::Captain::McpServersController < Api::V1::Accounts::BaseController
  before_action :ensure_custom_tools_enabled
  before_action -> { check_authorization(Captain::McpServer) }
  before_action :set_mcp_server, only: [:update, :destroy, :sync]

  def index
    @mcp_servers = account_mcp_servers.order(:created_at)
  end

  def create
    @mcp_server = account_mcp_servers.create!(mcp_server_params)
    @mcp_server.sync_tools!
    render :show
  rescue Captain::McpServer::LimitExceededError => e
    render_could_not_create_error(e.message)
  end

  # Connection changes list the tools again; tool toggles only update the enabled flags.
  def update
    @mcp_server.update!(mcp_server_params.merge(tools: toggled_tools))
    @mcp_server.sync_tools! if @mcp_server.saved_change_to_endpoint_url? || @mcp_server.saved_change_to_auth_token? ||
                               @mcp_server.saved_change_to_auth_type?
    render :show
  end

  def sync
    @mcp_server.sync_tools!
    render :show
  end

  def destroy
    @mcp_server.destroy!
    head :no_content
  end

  private

  def ensure_custom_tools_enabled
    return if Current.account.feature_enabled?('custom_tools') || Current.account.feature_enabled?('captain_integration_v2')

    render json: { error: 'Custom tools are not enabled for this account' }, status: :forbidden
  end

  def set_mcp_server
    @mcp_server = account_mcp_servers.find(params[:id])
  end

  def account_mcp_servers
    Current.account.captain_mcp_servers
  end

  def toggled_tools
    enabled = params.dig(:mcp_server, :enabled_tool_names)
    return @mcp_server.tools if enabled.nil?

    names = Array(enabled).map(&:to_s)
    @mcp_server.tools.map { |tool| tool.merge('enabled' => names.include?(tool['name'])) }
  end

  # A blank token on update keeps the saved one, since the token is never sent back to the browser.
  def mcp_server_params
    permitted = params.require(:mcp_server).permit(:name, :endpoint_url, :auth_type, :auth_header_name, :auth_token)
    permitted.delete(:auth_token) if @mcp_server && permitted[:auth_token].blank?
    permitted
  end
end

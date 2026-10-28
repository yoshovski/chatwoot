class Api::V1::Accounts::Captain::CustomToolsController < Api::V1::Accounts::BaseController
  before_action :ensure_custom_tools_enabled
  before_action -> { check_authorization(Captain::CustomTool) }
  before_action :set_custom_tool, only: [:show, :update, :destroy]

  def index
    @custom_tools = account_custom_tools
  end

  def show; end

  def create
    @custom_tool = account_custom_tools.new(custom_tool_params)
    assign_auth(@custom_tool)
    @custom_tool.save!
  rescue Captain::CustomTool::LimitExceededError => e
    render_could_not_create_error(e.message)
  end

  def update
    @custom_tool.assign_attributes(custom_tool_params)
    assign_auth(@custom_tool)
    @custom_tool.save!
  end

  def destroy
    @custom_tool.destroy
    head :no_content
  end

  def test
    tool = account_custom_tools.new(custom_tool_params)
    body = execute_test_request(tool)
    render json: { status: 200, body: body.to_s.truncate(500) }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  private

  def ensure_custom_tools_enabled
    return if Current.account.feature_enabled?('custom_tools') || Current.account.feature_enabled?('captain_integration_v2')

    render json: { error: 'Custom tools are not enabled for this account' }, status: :forbidden
  end

  def set_custom_tool
    @custom_tool = account_custom_tools.find(params[:id])
  end

  def account_custom_tools
    @account_custom_tools ||= Current.account.captain_custom_tools
  end

  def execute_test_request(tool)
    tool.valid?
    Captain::Tools::ActionRunner.new(tool, mode: :test).run(params: {}, contact: {}).last_request_body
  end

  # Auth values are write-only: secrets are stored encrypted and a blank secret keeps the saved one.
  def assign_auth(tool)
    auth_config = params.require(:custom_tool).permit(auth_config: {})[:auth_config]
    tool.assign_auth(auth_config) if auth_config || tool.will_save_change_to_auth_type?
  end

  def custom_tool_params
    params.require(:custom_tool).permit(
      :title,
      :description,
      :endpoint_url,
      :http_method,
      :request_template,
      :response_template,
      :auth_type,
      :enabled,
      param_schema: [:name, :type, :description, :required]
    )
  end
end

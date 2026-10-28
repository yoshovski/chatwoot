class Api::V1::Accounts::Captain::CustomToolsController < Api::V1::Accounts::BaseController
  TESTS_PER_MINUTE = 20
  TEST_RESPONSE_LIMIT = 50.kilobytes
  TEST_CONTACT = { email: 'test@example.com', phone_number: nil, name: 'Test Customer', verified: false }.freeze
  # Errors that stop a test run; a missing title or description doesn't.
  TEST_BLOCKING_ERRORS = /\A(steps|outputs|endpoint_url|param_schema)/

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

  # Runs the unsaved form against the real API with each param's test value and a sample contact. Every step runs,
  # whatever the execution mode; the page warns before steps that change data. Pass id to use the saved secrets.
  def test
    return render json: { error: I18n.t('captain.custom_tool.test_throttled') }, status: :too_many_requests if test_throttled?

    tool = test_tool
    return render_test_errors(tool) if test_blocking_errors?(tool)

    result = Captain::Tools::ActionRunner.new(tool, state: { account_id: Current.account.id }, mode: :test)
                                         .run(params: test_values(tool), contact: TEST_CONTACT, stop_after: params[:stop_after].presence)
    render json: { steps: result.step_results.map { |step| test_step_json(step) }, outputs: result.outputs, error_kind: result.error_kind }
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

  # Auth values are write-only: secrets are stored encrypted and a blank secret keeps the saved one.
  def assign_auth(tool)
    auth_config = params.require(:custom_tool).permit(auth_config: {})[:auth_config]
    tool.assign_auth(auth_config) if auth_config || tool.will_save_change_to_auth_type?
  end

  def render_record_invalid(exception)
    log_handled_error(exception)
    record = exception.record
    render json: { message: record.errors.full_messages.join(', '), attributes: record.errors.attribute_names,
                   errors: record.errors.to_hash }, status: :unprocessable_entity
  end

  # Never saved: the form's values on top of the stored tool (for its secrets) or a new one.
  def test_tool
    tool = params[:id].present? ? account_custom_tools.find(params[:id]) : account_custom_tools.new
    tool.assign_attributes(custom_tool_params)
    assign_auth(tool)
    tool
  end

  def test_throttled?
    key = format(::Redis::Alfred::CAPTAIN_ACTION_TEST_COUNT, user_id: Current.user.id, minute: Time.current.to_i / 60)
    count = Redis::Alfred.incr(key)
    Redis::Alfred.expire(key, 1.minute.to_i) if count == 1
    count > TESTS_PER_MINUTE
  end

  def test_blocking_errors?(tool)
    tool.validate
    tool.errors.attribute_names.any? { |attribute| TEST_BLOCKING_ERRORS.match?(attribute.to_s) }
  end

  def render_test_errors(tool)
    errors = tool.errors.to_hash.select { |attribute, _| TEST_BLOCKING_ERRORS.match?(attribute.to_s) }
    render json: { message: errors.values.flatten.join(', '), errors: errors }, status: :unprocessable_entity
  end

  def test_values(tool)
    overrides = params.fetch(:test_values, {}).permit!.to_h
    tool.param_schema.to_h { |param| [param['name'], param['test_value']] }.merge(overrides)
  end

  def test_step_json(step)
    json = step.slice(:key, :type, :ok, :status, :duration_ms, :error, :outputs, :missing_outputs, :compared)
    json[:request] = step[:request].merge(url: url_without_credentials(step[:request][:url])) if step[:request]
    json.merge!(test_response(step[:body])) if step.key?(:body)
    json
  end

  def test_response(body)
    return { response: body.byteslice(0, TEST_RESPONSE_LIMIT).scrub(''), response_truncated: true } if body.bytesize > TEST_RESPONSE_LIMIT

    { response: JSON.parse(body) }
  rescue JSON::ParserError
    { response: body }
  end

  def url_without_credentials(url) = url.to_s.sub(%r{\A(https?://)[^/@]*@}i, '\\1')

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
      :execution_mode,
      param_schema: [:name, :type, :description, :required, :test_value],
      steps: [:key, :type, :method, :url, :body_type, :body, :left, :right, :compare, :require_verified_contact, { headers: [:name, :value] }],
      outputs: [:key, :step, :path, :type, :available_to_ai, :required],
      messages: [:confirm_prompt, :success, :failure]
    )
  end
end

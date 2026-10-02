class Api::V1::Accounts::AiAgents::KnowledgeController < Api::V1::Accounts::BaseController
  wrap_parameters false

  UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  READ_ACTIONS = %w[index show entries sources entry_revisions source_revisions agent_bases jobs retrieve validate_citations original].freeze
  ENTRY_FIELDS = %w[question answer source_id source_revision_id provenance review_state].freeze
  SOURCE_FIELDS = %w[name text source_url provenance original_base64 filename media_type].freeze
  PAYLOAD_FIELDS = {
    'create' => %w[name], 'update' => %w[name enabled], 'create_entry' => ENTRY_FIELDS,
    'edit_entry' => ENTRY_FIELDS + %w[expected_version], 'create_source' => SOURCE_FIELDS,
    'edit_source' => SOURCE_FIELDS + %w[expected_version], 'entry_state' => %w[enabled],
    'source_state' => %w[enabled], 'review_entry' => %w[review_state], 'retrieve' => %w[query top_k],
    'validate_citations' => %w[binding_ids], 'ensure_agent' => %w[chatwoot_agent_bot_id]
  }.freeze

  before_action :authorize_knowledge
  before_action :validate_identifiers
  before_action :validate_payload

  def index
    forward(:get, '/bases')
  end

  def show
    forward(:get, "/bases/#{params[:base_id]}")
  end

  def create
    forward(:post, '/bases')
  end

  def update
    forward(:patch, "/bases/#{params[:base_id]}")
  end

  def rebuild
    forward(:post, "/bases/#{params[:base_id]}/rebuild")
  end

  def entries
    forward(:get, "/bases/#{params[:base_id]}/entries")
  end

  def create_entry
    forward(:post, "/bases/#{params[:base_id]}/entries")
  end

  def edit_entry
    forward(:put, "/entries/#{params[:entry_id]}")
  end

  def entry_state
    forward(:patch, "/entries/#{params[:entry_id]}/state")
  end

  def review_entry
    forward(:patch, "/entries/#{params[:entry_id]}/review")
  end

  def entry_revisions
    forward(:get, "/entries/#{params[:entry_id]}/revisions")
  end

  def sources
    forward(:get, "/bases/#{params[:base_id]}/sources")
  end

  def create_source
    forward(:post, "/bases/#{params[:base_id]}/sources")
  end

  def edit_source
    forward(:put, "/sources/#{params[:source_id]}")
  end

  def source_state
    forward(:patch, "/sources/#{params[:source_id]}/state")
  end

  def source_revisions
    forward(:get, "/sources/#{params[:source_id]}/revisions")
  end

  def original
    forward(:get, "/source-revisions/#{params[:revision_id]}/original")
  end

  def ensure_agent
    bot_id = request.request_parameters['chatwoot_agent_bot_id']
    unless bot_id.is_a?(Integer) && bot_id.positive?
      return render json: { error: I18n.t('errors.ai_knowledge.invalid_bot_id') }, status: :unprocessable_entity
    end

    Current.account.agent_bots.find(bot_id)
    forward(:post, '/agents')
  end

  def agent_bases
    forward(:get, "/agents/#{params[:agent_id]}/bases")
  end

  def attach
    forward(:put, "/agents/#{params[:agent_id]}/bases/#{params[:base_id]}")
  end

  def detach
    forward(:delete, "/agents/#{params[:agent_id]}/bases/#{params[:base_id]}")
  end

  def jobs
    forward(:get, "/bases/#{params[:base_id]}/jobs")
  end

  def retry_job
    forward(:post, "/jobs/#{params[:job_id]}/retry")
  end

  def retrieve
    forward(:post, "/bases/#{params[:base_id]}/retrieve")
  end

  def validate_citations
    forward(:post, "/bases/#{params[:base_id]}/citations/validate")
  end

  private

  def authorize_knowledge
    authorized = Current.user && Current.account_user && Current.account.feature_enabled?('native_ai_knowledge')
    raise Pundit::NotAuthorizedError unless authorized
    return if READ_ACTIONS.include?(action_name)

    check_admin_authorization?
  end

  def validate_identifiers
    valid = %i[base_id agent_id entry_id source_id revision_id job_id].all? do |key|
      params[key].nil? || (params[key].is_a?(String) && UUID_PATTERN.match?(params[key]))
    end
    render json: { error: I18n.t('errors.ai_knowledge.invalid_identifier') }, status: :unprocessable_entity unless valid
  end

  def validate_payload
    fields = PAYLOAD_FIELDS.fetch(action_name, [])
    body = request.request_parameters
    return render json: { error: I18n.t('errors.ai_knowledge.unexpected_parameters') }, status: :unprocessable_entity if (body.keys - fields).any?

    payload = params.permit(*fields.excluding('provenance', 'binding_ids'), provenance: {}, binding_ids: []).to_h.slice(*fields)
    return render json: { error: I18n.t('errors.ai_knowledge.invalid_parameter_shape') }, status: :unprocessable_entity unless payload == body

    @knowledge_payload = body.empty? ? nil : payload
  end

  def forward(method, path)
    response = AiAgents::KnowledgeClient.new(account: Current.account, actor: Current.user).request(
      method: method, path: "/v1/knowledge#{path}",
      action: READ_ACTIONS.include?(action_name) ? 'knowledge:read' : 'knowledge:write',
      payload: @knowledge_payload
    )
    if response.code == 204
      head :no_content
    elsif action_name == 'original' && response.code == 200
      send_data response.body, type: 'application/octet-stream', disposition: 'attachment'
    else
      render json: response.parsed_response, status: response.code
    end
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED
    render json: { error: I18n.t('errors.ai_knowledge.unavailable') }, status: :bad_gateway
  end
end

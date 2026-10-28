# == Schema Information
#
# Table name: captain_custom_tools
#
#  id                :bigint           not null, primary key
#  auth_config       :jsonb
#  auth_type         :string           default("none")
#  description       :text
#  enabled           :boolean          default(TRUE), not null
#  encrypted_auth    :text
#  endpoint_url      :text             not null
#  execution_mode    :string           default("background"), not null
#  http_method       :string           default("GET"), not null
#  messages          :jsonb            not null
#  outputs           :jsonb            not null
#  param_schema      :jsonb
#  request_template  :text
#  response_template :text
#  slug              :string           not null
#  steps             :jsonb            not null
#  title             :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#
# Indexes
#
#  index_captain_custom_tools_on_account_id           (account_id)
#  index_captain_custom_tools_on_account_id_and_slug  (account_id,slug) UNIQUE
#
class Captain::CustomTool < ApplicationRecord
  class LimitExceededError < StandardError; end

  MAX_PER_ACCOUNT = 15

  include Concerns::Toolable
  include Concerns::SafeEndpointValidatable
  include Concerns::ActionSteps

  self.table_name = 'captain_custom_tools'

  NAME_PREFIX = 'custom'.freeze
  NAME_SEPARATOR = '_'.freeze
  # OpenAI enforces a 64-char limit on function names. The slug is used
  # verbatim as the tool name in LLM requests, so it must fit within this limit.
  MAX_SLUG_LENGTH = 64
  COLLISION_SUFFIX_LENGTH = 7 # "_" + 6 random alphanumeric chars
  PARAM_SCHEMA_VALIDATION = {
    'type': 'array',
    'items': {
      'type': 'object',
      'properties': {
        'name': { 'type': 'string' },
        'type': { 'type': 'string' },
        'description': { 'type': 'string' },
        'required': { 'type': 'boolean' },
        'test_value': { 'type': 'string' }
      },
      'required': %w[name type description],
      'additionalProperties': false
    }
  }.to_json.freeze

  # Auth values that are only stored encrypted and never sent back to the browser.
  SECRET_AUTH_KEYS = %w[token password key].freeze

  belongs_to :account

  encrypts :encrypted_auth if Chatwoot.encryption_configured?

  enum :http_method, %w[GET POST].index_by(&:itself), validate: true
  enum :auth_type, %w[none bearer basic api_key].index_by(&:itself), default: :none, validate: true, prefix: :auth
  enum :execution_mode, %w[background confirm].index_by(&:itself), validate: true

  before_validation :generate_slug
  before_validation :store_step_secrets
  before_create :ensure_within_limit

  validates :slug, presence: true, uniqueness: { scope: :account_id }, length: { maximum: MAX_SLUG_LENGTH }
  validates :title, presence: true
  validates :endpoint_url, presence: true
  validates_with JsonSchemaValidator,
                 schema: PARAM_SCHEMA_VALIDATION,
                 attribute_resolver: ->(record) { record.param_schema }

  scope :enabled, -> { where(enabled: true) }

  def to_tool_metadata
    {
      id: slug,
      title: title,
      description: description,
      emoji: '🔌',
      custom: true
    }
  end

  def auth_secrets
    encrypted_auth.present? ? JSON.parse(encrypted_auth) : {}
  end

  # Secrets win over legacy auth_config values, which existing rows keep until they are saved through the API.
  def auth_value(name)
    auth_secrets[name].presence || auth_config.to_h[name]
  end

  # Stores the given auth values: secrets go encrypted, the rest (header name, username) into auth_config.
  # A blank secret keeps the stored one, since the browser never gets it back; a new auth type starts empty.
  def assign_auth(values)
    values = values.to_h.stringify_keys
    kept = will_save_change_to_auth_type? ? auth_secrets.slice('steps') : auth_secrets
    write_secrets(kept.merge(values.slice(*SECRET_AUTH_KEYS).compact_blank))
    self.auth_config = values.except(*SECRET_AUTH_KEYS)
  end

  def public_auth_config = auth_config.to_h.except(*SECRET_AUTH_KEYS)

  def auth_configured?
    SECRET_AUTH_KEYS.any? { |key| auth_value(key).present? }
  end

  # The auth a request step sends: its own, another step's ("same_as") or, for steps saved without one, the
  # action's. An own secret falls back to the action's when the types match, so a step that takes over the
  # action's auth keeps working before its secret is entered again.
  def request_auth(step)
    auth = step['auth']
    return action_auth if auth.blank?
    return request_auth(request_steps.find { |other| other['key'] == auth['same_as'] } || {}) if auth['same_as'].present?

    own_request_auth(step['key'], auth)
  end

  # Steps as the API returns them: each request step says whether its auth has a saved secret.
  def public_steps
    steps.map { |step| step['type'] == 'request' ? step.merge('auth_configured' => request_auth_configured?(step)) : step }
  end

  def enabled_scenarios_count
    Captain::Scenario.enabled.where(account_id: account_id).where('tools @> ?', [slug].to_json).count
  end

  private

  def action_auth
    { 'type' => auth_type, 'username' => auth_config.to_h['username'], 'name' => auth_config.to_h['name'] }
      .merge(SECRET_AUTH_KEYS.index_with { |key| auth_value(key) })
  end

  def own_request_auth(step_key, auth)
    own = auth_secrets.dig('steps', step_key) || {}
    fallback = auth['type'] == auth_type ? action_auth : {}
    auth.slice('type', 'username', 'name').merge(SECRET_AUTH_KEYS.index_with { |key| own[key].presence || fallback[key] })
  end

  def request_auth_configured?(step)
    SECRET_AUTH_KEYS.any? { |key| request_auth(step)[key].present? }
  end

  # Secrets sent inside a step's auth move into the encrypted column. A blank one keeps the stored secret unless
  # the step's auth type changed; secrets of removed steps are dropped.
  def store_step_secrets
    previous_types = Array(steps_was).to_h { |step| [step['key'], step.dig('auth', 'type')] }
    step_secrets = request_steps.filter_map do |step|
      secrets = take_step_secrets(step, previous_types[step['key']])
      [step['key'], secrets] if secrets.present?
    end.to_h
    write_secrets(auth_secrets.except('steps').merge(step_secrets.present? ? { 'steps' => step_secrets } : {}))
  end

  # Removes the secrets from the step's auth and returns them, on top of the stored ones when the type is the same.
  def take_step_secrets(step, previous_type)
    auth = step['auth']
    return if auth.blank? || auth['same_as'].present?

    kept = previous_type == auth['type'] ? auth_secrets.dig('steps', step['key']).to_h : {}
    step['auth'] = auth.except(*SECRET_AUTH_KEYS)
    kept.merge(auth.slice(*SECRET_AUTH_KEYS).compact_blank)
  end

  def write_secrets(secrets)
    self.encrypted_auth = secrets.presence&.to_json
  end

  def ensure_within_limit
    # Lock the account row to serialize concurrent creates and prevent exceeding the cap
    Account.lock.find(account_id)
    return if account.captain_custom_tools.count < MAX_PER_ACCOUNT

    raise LimitExceededError, I18n.t('captain.custom_tool.limit_exceeded', limit: MAX_PER_ACCOUNT)
  end

  def generate_slug
    return if slug.present?
    return if title.blank?

    parameterized_title = title.parameterize(separator: NAME_SEPARATOR)
    base_slug = "#{NAME_PREFIX}#{NAME_SEPARATOR}#{parameterized_title}".truncate(MAX_SLUG_LENGTH, omission: '')
    self.slug = find_unique_slug(base_slug)
  end

  def find_unique_slug(base_slug)
    return base_slug unless slug_exists?(base_slug)

    truncated = base_slug.truncate(MAX_SLUG_LENGTH - COLLISION_SUFFIX_LENGTH, omission: '')
    5.times do
      slug_candidate = "#{truncated}#{NAME_SEPARATOR}#{SecureRandom.alphanumeric(6).downcase}"
      return slug_candidate unless slug_exists?(slug_candidate)
    end

    raise ActiveRecord::RecordNotUnique, I18n.t('captain.custom_tool.slug_generation_failed')
  end

  def slug_exists?(candidate)
    self.class.exists?(account_id: account_id, slug: candidate)
  end
end

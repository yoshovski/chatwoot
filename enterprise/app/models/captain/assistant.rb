# == Schema Information
#
# Table name: captain_assistants
#
#  id                  :bigint           not null, primary key
#  config              :jsonb            not null
#  description         :text
#  guardrails          :jsonb
#  name                :string           not null
#  response_guidelines :jsonb
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#
# Indexes
#
#  index_captain_assistants_on_account_id  (account_id)
#
# rubocop:disable Metrics/ClassLength
class Captain::Assistant < ApplicationRecord
  DESCRIPTION_LENGTH_LIMIT = 500
  CITATION_SOURCES_STATE_KEY = :captain_v2_citation_sources
  CITATION_DETAILS_STATE_KEY = :captain_v2_citation_details
  PRODUCT_HANDLES_STATE_KEY = :captain_v2_product_handles
  PRODUCT_SEARCH_STATS_STATE_KEY = :captain_v2_product_search_stats
  SHOPIFY_CATALOG_TOOL_IDS = %w[catalog_product_search browse_catalog].freeze
  AUTO_RESOLVE_MODES = %w[disabled legacy evaluated].freeze
  DEFAULT_INACTIVITY_THRESHOLD_MINUTES = 60
  MINIMUM_INACTIVITY_THRESHOLD_MINUTES = 5
  MAXIMUM_INACTIVITY_THRESHOLD_MINUTES = 1.day.in_minutes.to_i
  INACTIVITY_THRESHOLD_STEP_MINUTES = 5
  RESPONSE_WINDOWS = %w[always business_hours outside_business_hours].freeze
  DEFAULT_MAX_SUGGESTED_REPLIES = 3
  MINIMUM_MAX_SUGGESTED_REPLIES = 1
  MAXIMUM_MAX_SUGGESTED_REPLIES = 5

  include Avatarable
  include Concerns::CaptainToolsHelpers
  include Concerns::Agentable

  self.table_name = 'captain_assistants'

  belongs_to :account
  has_many :documents, class_name: 'Captain::Document', dependent: :destroy_async
  has_many :responses, class_name: 'Captain::AssistantResponse', dependent: :destroy_async
  has_many :faq_suggestions, class_name: 'Captain::FaqSuggestion', dependent: :destroy_async
  has_many :captain_inboxes,
           class_name: 'CaptainInbox',
           foreign_key: :captain_assistant_id,
           dependent: :destroy_async
  has_many :inboxes,
           through: :captain_inboxes
  has_many :messages, as: :sender, dependent: :nullify
  has_many :copilot_threads, dependent: :destroy_async
  has_many :scenarios, class_name: 'Captain::Scenario', dependent: :destroy_async
  has_many :agent_sessions, class_name: 'Captain::AgentSession', dependent: :destroy_async
  has_many :conversation_outcomes, dependent: :destroy_async
  has_many :assigned_conversations, as: :ai_assignee, class_name: '::Conversation', foreign_key: :assignee_agent_bot_id,
                                    dependent: :nullify, inverse_of: :ai_assignee

  PRODUCT_CACHE_STATE_KEY = :captain_v2_product_cache

  store_accessor :config, :temperature, :feature_faq, :feature_memory, :feature_contact_attributes, :product_name,
                 :auto_resolve_mode, :auto_resolve_after, :send_inactivity_resolution_message, :response_window,
                 :continue_while_waiting, :suggested_replies, :max_suggested_replies, :product_cards,
                 :link_allowlist, :image_allowlist, :handoff_safety_net, :handoff_safety_net_keywords,
                 :reply_labels, :reply_label_keywords, :outcome_labels,
                 :handoff_fallback_agent_id, :handoff_fallback_team_id

  BOOLEAN_CONFIG_KEYS = %w[
    feature_faq
    feature_memory
    feature_citation
    feature_contact_attributes
    continue_while_waiting
    send_inactivity_resolution_message
    suggested_replies
    product_cards
    handoff_safety_net
    reply_labels
    outcome_labels
  ].freeze

  before_validation :set_default_auto_resolve_mode, on: :create
  before_validation :normalize_auto_resolve_after
  before_validation :normalize_boolean_config_attributes
  before_validation :normalize_max_suggested_replies
  before_validation :normalize_allowlists
  before_validation :normalize_keywords
  before_validation :normalize_fallback_assignments

  validates :name, presence: true
  validates :description, presence: true, length: { maximum: DESCRIPTION_LENGTH_LIMIT }
  validates :account_id, presence: true
  validates_with Captain::AudienceValidator
  validate :validate_response_window
  validate :validate_handoff_fallback_assignments
  validates :auto_resolve_mode, inclusion: { in: AUTO_RESOLVE_MODES }
  validates :send_inactivity_resolution_message, inclusion: { in: [true, false] }
  validates :auto_resolve_after,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: MINIMUM_INACTIVITY_THRESHOLD_MINUTES,
              less_than_or_equal_to: MAXIMUM_INACTIVITY_THRESHOLD_MINUTES
            },
            allow_nil: true
  validates :max_suggested_replies,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: MINIMUM_MAX_SUGGESTED_REPLIES,
              less_than_or_equal_to: MAXIMUM_MAX_SUGGESTED_REPLIES
            },
            allow_nil: true

  scope :ordered, -> { order(created_at: :desc) }

  scope :for_account, ->(account_id) { where(account_id: account_id) }

  def available_name
    name
  end

  def engages?(contact, conversation)
    responds_to_audience?(contact, conversation) && available_now?(conversation)
  end

  def responds_to_audience?(contact, conversation)
    return true if config['audience'].blank?

    Captain::AudienceMatcher.new(config['audience']).matches?(contact, conversation)
  end

  def available_now?(conversation)
    response_window = config['response_window']
    return true if response_window.blank? || response_window == 'always'

    inbox = conversation.inbox
    return true unless inbox.working_hours_enabled?

    response_window == 'business_hours' ? !inbox.out_of_office? : inbox.out_of_office?
  end

  def auto_resolve_mode
    config.fetch('auto_resolve_mode') { account&.captain_auto_resolve_mode || 'evaluated' }
  end

  def inactive_conversation_resolution_disabled?
    auto_resolve_mode == 'disabled'
  end

  def evaluate_inactive_conversations_before_resolving?
    auto_resolve_mode == 'evaluated'
  end

  def inactivity_threshold_minutes
    return DEFAULT_INACTIVITY_THRESHOLD_MINUTES unless account.feature_enabled?('captain_integration_v2')

    (config['auto_resolve_after'] || DEFAULT_INACTIVITY_THRESHOLD_MINUTES).to_i
  end

  def send_inactivity_resolution_message
    return true unless account.feature_enabled?('captain_integration_v2')

    val = config.fetch('send_inactivity_resolution_message', true)
    return true if val.nil?

    ActiveModel::Type::Boolean.new.cast(val)
  end

  def send_inactivity_resolution_message?
    send_inactivity_resolution_message
  end

  # Order tracking only needs a connected store and its tool key. The catalog tools also need the catalog sync on.
  def shopify_order_tracking_available? = shopify_tools_hook.present?

  def shopify_catalog_tools_available?
    shopify_tools_hook&.shopify_catalog_client_status == 'on'
  end

  def commerce_enabled? = shopify_catalog_tools_available? || shopify_order_tracking_available?

  def available_agent_tools
    tools = self.class.built_in_agent_tools.dup
    tools.reject! { |tool| SHOPIFY_CATALOG_TOOL_IDS.include?(tool[:id]) } unless shopify_catalog_tools_available?
    tools.reject! { |tool| tool[:id] == 'track_order' } unless shopify_order_tracking_available?

    custom_tools = account.captain_custom_tools.enabled.map(&:to_tool_metadata)
    tools.concat(custom_tools)

    tools
  end

  def available_tool_ids = available_agent_tools.pluck(:id)

  def known_tool_ids
    self.class.built_in_tool_ids + account.captain_custom_tools.pluck(:slug)
  end

  def agent_name
    name.parameterize(separator: '_')
  end

  def handoff_fallback_agent
    return if handoff_fallback_agent_id.blank?

    account&.users&.find_by(id: handoff_fallback_agent_id)
  end

  def handoff_fallback_team
    return if handoff_fallback_team_id.blank?

    account&.teams&.find_by(id: handoff_fallback_team_id)
  end

  # Scenarios start from these tools too, so they can search knowledge and products mid-flow.
  def agent_tools
    tool_ids = %w[faq_lookup handoff]
    tool_ids += SHOPIFY_CATALOG_TOOL_IDS if shopify_catalog_tools_available?
    tool_ids << 'track_order' if shopify_order_tracking_available?

    tools = tool_ids.map { |tool_id| self.class.resolve_tool_class(tool_id).new(self) }
    tools.concat(account.captain_custom_tools.enabled.map { |custom_tool| custom_tool.tool(self) })
  end

  def push_event_data
    assistant_event_data
  end

  def webhook_data
    assistant_event_data
  end

  def customer_visible_citation_urls(citation_sources, details: {}, allowed_product_handles: nil)
    Captain::Knowledge::CitationSources.new(self).urls(
      citation_sources,
      details: details,
      allowed_product_handles: allowed_product_handles
    )
  end

  def citations_enabled?
    config['feature_citation']
  end

  def handoff_safety_net?
    ActiveModel::Type::Boolean.new.cast(config['handoff_safety_net']) == true
  end

  def reply_labels?
    ActiveModel::Type::Boolean.new.cast(config['reply_labels']) == true
  end

  def outcome_labels?
    ActiveModel::Type::Boolean.new.cast(config['outcome_labels']) == true
  end

  def trusted_citation_urls(run_result)
    return {} unless citations_enabled?

    citation_document_ids = run_result&.context&.dig(:state, CITATION_SOURCES_STATE_KEY) || {}
    details = run_result&.context&.dig(:state, CITATION_DETAILS_STATE_KEY) || {}
    product_handles = run_result_product_handles(run_result)
    customer_visible_citation_urls(citation_document_ids, details: details, allowed_product_handles: product_handles)
  end

  def run_result_product_handles(run_result)
    state = run_result&.context&.dig(:state)
    state&.dig(PRODUCT_HANDLES_STATE_KEY) || state&.dig(:product_handles)
  end

  def run_result_product_search_stats(run_result)
    state = run_result&.context&.dig(:state)
    return unless state

    raw_stats = state[PRODUCT_SEARCH_STATS_STATE_KEY] || state[:product_search_stats] || state['product_search_stats']
    return if raw_stats.blank?

    stats = raw_stats.with_indifferent_access
    { searches: stats[:searches].to_i, results: stats[:results].to_i }
  end

  def prompt_context
    {
      name: name,
      description: description,
      product_name: config['product_name'] || 'this product',
      commerce_enabled: commerce_enabled?,
      scenarios: scenarios.enabled.map do |scenario|
        {
          title: scenario.title,
          key: Agents::Helpers::NameNormalizer.to_tool_name(scenario.handoff_key),
          description: scenario.description
        }
      end,
      response_guidelines: response_guidelines || [],
      guardrails: guardrails || []
    }
  end

  def default_avatar_url
    "#{ENV.fetch('FRONTEND_URL', nil)}/assets/images/dashboard/captain/ai-agent-avatar.svg"
  end

  def continue_while_waiting?
    return false if config.blank?

    ActiveModel::Type::Boolean.new.cast(config['continue_while_waiting']) == true
  end

  def suggested_replies?
    return false if config.blank?

    ActiveModel::Type::Boolean.new.cast(config['suggested_replies']) == true
  end

  def max_suggested_replies
    val = config&.dig('max_suggested_replies')
    return DEFAULT_MAX_SUGGESTED_REPLIES if val.blank?

    val.to_i.clamp(MINIMUM_MAX_SUGGESTED_REPLIES, MAXIMUM_MAX_SUGGESTED_REPLIES)
  end

  def product_cards?
    return false if config.blank?

    ActiveModel::Type::Boolean.new.cast(config['product_cards']) == true
  end

  def link_allowlist
    configured = Array(config&.dig('link_allowlist')).map(&:to_s).map(&:strip).reject(&:blank?)
    return configured if configured.present?

    default_link_allowlist
  end

  def image_allowlist
    configured = Array(config&.dig('image_allowlist')).map(&:to_s).map(&:strip).reject(&:blank?)
    return configured if configured.present?

    default_image_allowlist
  end

  def default_link_allowlist
    shopify_store_base_urls
  end

  def default_image_allowlist
    ['https://cdn.shopify.com/', *shopify_store_base_urls.map { |base_url| "#{base_url}cdn/" }]
  end

  private

  def shopify_tools_hook
    hook = account.hooks.find_by(app_id: 'shopify')
    hook if hook&.shopify_connected? && hook.shopify_tool_key.present?
  end

  # The connected store's myshopify domain (with and without www) and its public storefront.
  def shopify_store_base_urls
    hook = account.hooks.find_by(app_id: 'shopify')
    return [] unless hook&.shopify_connected? && hook.reference_id.present?

    domain = hook.reference_id.downcase.strip
    base_urls = ["https://#{domain}/"]
    base_urls << "https://www.#{domain}/" unless domain.start_with?('www.')
    if hook.shopify_storefront_url.present?
      storefront_url = hook.shopify_storefront_url.strip
      storefront_url = "https://#{storefront_url}" unless storefront_url.start_with?('http://', 'https://')
      base_urls << "#{storefront_url.chomp('/')}/"
    end
    base_urls.uniq
  end

  def assistant_event_data
    {
      id: id,
      name: name,
      available_name: name,
      avatar_url: avatar_url.presence || default_avatar_url,
      description: description,
      created_at: created_at,
      type: 'captain_assistant'
    }
  end

  def normalize_auto_resolve_after
    threshold = Integer(auto_resolve_after.to_s, exception: false)
    return unless threshold&.between?(MINIMUM_INACTIVITY_THRESHOLD_MINUTES, MAXIMUM_INACTIVITY_THRESHOLD_MINUTES)

    # Keep API values aligned with the five minute options available in the settings UI.
    self.auto_resolve_after = (threshold.fdiv(INACTIVITY_THRESHOLD_STEP_MINUTES).round * INACTIVITY_THRESHOLD_STEP_MINUTES)
  end

  def normalize_boolean_config_attributes
    return unless config.is_a?(Hash)

    BOOLEAN_CONFIG_KEYS.each do |key|
      next unless config.key?(key)

      config[key] = ActiveModel::Type::Boolean.new.cast(config[key])
    end
  end

  def normalize_max_suggested_replies
    return if config.blank? || config['max_suggested_replies'].blank?

    count = Integer(config['max_suggested_replies'].to_s, exception: false)
    self.max_suggested_replies = count.clamp(MINIMUM_MAX_SUGGESTED_REPLIES, MAXIMUM_MAX_SUGGESTED_REPLIES) if count
  end

  def normalize_allowlists
    return unless config.is_a?(Hash)

    normalize_allowlist_key('link_allowlist')
    normalize_allowlist_key('image_allowlist')
  end

  def normalize_allowlist_key(key)
    return unless config.key?(key)

    config[key] = Array(config[key]).map(&:to_s).map(&:strip).reject(&:blank?).uniq
  end

  def normalize_keywords
    return unless config.is_a?(Hash)

    normalize_safety_net_keywords
    normalize_reply_label_keywords
  end

  def normalize_safety_net_keywords
    return unless config.key?('handoff_safety_net_keywords')

    config['handoff_safety_net_keywords'] = Array(config['handoff_safety_net_keywords']).map(&:to_s).map(&:strip).reject(&:blank?)
  end

  def normalize_reply_label_keywords
    return unless config.key?('reply_label_keywords')

    raw = config['reply_label_keywords']
    config['reply_label_keywords'] = if raw.is_a?(Hash)
                                       raw.transform_values { |v| Array(v).map(&:to_s).map(&:strip).reject(&:blank?) }
                                     else
                                       {}
                                     end
  end

  def validate_response_window
    response_window = config['response_window']
    return if response_window.blank?

    errors.add(:config, 'invalid response_window') unless RESPONSE_WINDOWS.include?(response_window)
  end

  def set_default_auto_resolve_mode
    return if config.key?('auto_resolve_mode')

    self.auto_resolve_mode = account&.captain_auto_resolve_mode || 'evaluated'
  end

  def normalize_fallback_assignments
    return unless config.is_a?(Hash)

    %w[handoff_fallback_agent_id handoff_fallback_team_id].each do |key|
      if config.key?(key)
        val = config[key]
        config[key] = val.present? ? Integer(val.to_s, exception: false) : nil
      elsif config.key?(key.to_sym)
        val = config.delete(key.to_sym)
        config[key] = val.present? ? Integer(val.to_s, exception: false) : nil
      end
    end
  end

  def validate_handoff_fallback_assignments
    validate_handoff_fallback_agent
    validate_handoff_fallback_team
  end

  def validate_handoff_fallback_agent
    return if handoff_fallback_agent_id.blank?
    return unless account

    agent = account.users.find_by(id: handoff_fallback_agent_id)
    unless agent
      errors.add(:handoff_fallback_agent_id, 'must belong to the account')
      return
    end

    return if inboxes.empty?
    return if inboxes.all? { |inbox| inbox.inbox_members.exists?(user_id: agent.id) }

    errors.add(:handoff_fallback_agent_id, 'must be a member of the inbox')
  end

  def validate_handoff_fallback_team
    return if handoff_fallback_team_id.blank?
    return unless account

    return if account.teams.exists?(id: handoff_fallback_team_id)

    errors.add(:handoff_fallback_team_id, 'must belong to the account')
  end
end
# rubocop:enable Metrics/ClassLength

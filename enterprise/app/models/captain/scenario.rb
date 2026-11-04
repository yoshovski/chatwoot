# == Schema Information
#
# Table name: captain_scenarios
#
#  id           :bigint           not null, primary key
#  description  :text
#  enabled      :boolean          default(TRUE), not null
#  instruction  :text
#  title        :string
#  tools        :jsonb
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#  assistant_id :bigint           not null
#
# Indexes
#
#  index_captain_scenarios_on_account_id                (account_id)
#  index_captain_scenarios_on_assistant_id              (assistant_id)
#  index_captain_scenarios_on_assistant_id_and_enabled  (assistant_id,enabled)
#  index_captain_scenarios_on_enabled                   (enabled)
#
class Captain::Scenario < ApplicationRecord
  DESCRIPTION_LENGTH_LIMIT = 500

  include Concerns::CaptainToolsHelpers
  include Concerns::Agentable

  # OpenAI enforces a 64-char limit on function names. The ai-agents gem
  # prepends "handoff_to_" (11 chars), so we keep a safety margin and cap
  # the full tool name to MAX_HANDOFF_TOOL_NAME_LENGTH (60 chars).
  # Format: "scenario_{id}_{slug}_agent" for persisted records (stable + readable),
  # and "scenario_draft_{slug}_agent" for unsaved records, with slug truncated
  # based on the available length budget.
  HANDOFF_TOOL_PREFIX = 'handoff_to_'.freeze
  HANDOFF_KEY_PREFIX = 'scenario'.freeze
  HANDOFF_KEY_SUFFIX = 'agent'.freeze
  MAX_HANDOFF_TOOL_NAME_LENGTH = 60
  MAX_AGENT_NAME_LENGTH = MAX_HANDOFF_TOOL_NAME_LENGTH - HANDOFF_TOOL_PREFIX.length
  MAX_HANDOFF_SLUG_LENGTH = 24

  self.table_name = 'captain_scenarios'

  belongs_to :assistant, class_name: 'Captain::Assistant'
  belongs_to :account

  validates :title, presence: true
  validates :description, presence: true, length: { maximum: DESCRIPTION_LENGTH_LIMIT }
  validates :instruction, presence: true
  validates :assistant_id, presence: true
  validates :account_id, presence: true
  validate :validate_instruction_tools

  scope :enabled, -> { where(enabled: true) }

  delegate :temperature, :feature_faq, :feature_memory, :product_name, :response_guidelines, :guardrails, to: :assistant

  before_save :resolve_tool_references

  def handoff_key
    [handoff_id_key, compact_handoff_slug, HANDOFF_KEY_SUFFIX].compact.join('_')
  end

  def prompt_context
    behaviour = Captain::Behaviour.for(assistant).prompt_context
    {
      **behaviour.slice(:lead_capture, :behaviour, :reply_schema_v2),
      title: title,
      instructions: resolved_instructions,
      tools: resolved_tools,
      commerce_enabled: assistant.commerce_enabled?,
      **behaviour.slice(
        :answer_format, :answer_length, :answer_length_instruction, :follow_up_questions, :helpful_links_mode, :published_pricing_enabled
      ),
      feature_citation: assistant.citations_enabled?,
      # Same normalization the agents gem uses for handoff tool names, so the prompt names a tool that exists.
      assistant_name: Agents::Helpers::NameNormalizer.to_tool_name(assistant.agent_name),
      response_guidelines: response_guidelines || [],
      guardrails: guardrails || [],
      off_limits_message: assistant.off_limits_message.presence,
      product_name: product_name || 'this product',
      limits: behaviour.fetch(:limits)
    }
  end

  private

  def agent_name
    handoff_key
  end

  def handoff_id_key
    return "#{HANDOFF_KEY_PREFIX}_#{id}" if id.present?

    "#{HANDOFF_KEY_PREFIX}_draft"
  end

  def compact_handoff_slug
    slug = title.to_s.parameterize(separator: '_').presence
    return nil if slug.blank?

    max_slug_length = [MAX_HANDOFF_SLUG_LENGTH, dynamic_slug_max_length].min
    return nil if max_slug_length <= 0

    slug.first(max_slug_length).sub(/_+\z/, '').presence
  end

  def dynamic_slug_max_length
    # handoff_to_#{scenario_<id>_<slug>_agent}
    MAX_AGENT_NAME_LENGTH - handoff_id_key.length - HANDOFF_KEY_SUFFIX.length - 2
  end

  # The assistant's tools plus the ones the instruction names, such as add_private_note.
  def agent_tools
    named_tools = resolved_tools.filter_map { |tool| resolve_tool_instance(tool) }
    (assistant.agent_tools + named_tools).uniq(&:name)
  end

  # A reference with fixed parameters names its own tool and says what it's fixed to:
  # "`update_contact_attribute__company_size` tool (saves the contact's Company size)".
  def resolved_instructions
    instruction.gsub(TOOL_REFERENCE_WITH_PARAMS_REGEX) do
      match = Regexp.last_match
      reference = extract_tool_references(match[0]).first
      fixed_tool_class = fixed_params_tool_class(reference[:id]) if reference[:params].present?
      next "`#{match[:id]}` tool" unless fixed_tool_class

      summary = fixed_tool_class.fixed_summary(assistant, reference[:params])
      "`#{fixed_tool_class.reference_key(reference[:params])}` tool#{" (#{summary})" if summary}"
    end
  end

  # Tool metadata for the prompt and the agent. A built-in named with fixed parameters appears once per reference.
  def resolved_tools
    return [] if tools.blank?

    available_tools = assistant.available_agent_tools
    references = extract_tool_references(instruction)
    resolved = tools.flat_map do |tool_id|
      metadata = available_tools.find { |tool| tool[:id] == tool_id }
      metadata ? tool_reference_metadata(metadata, references) : []
    end
    resolved.uniq { |tool| tool[:id] }
  end

  def tool_reference_metadata(metadata, references)
    tool_references = references.select { |reference| reference[:id] == metadata[:id] }
    tool_references.map { |reference| fixed_params_metadata(metadata, reference[:params]) }.presence || [metadata]
  end

  def fixed_params_metadata(metadata, params)
    tool_class = fixed_params_tool_class(metadata[:id]) if params.present?
    return metadata unless tool_class

    summary = tool_class.fixed_summary(assistant, params)
    metadata.merge(id: tool_class.reference_key(params), tool_id: metadata[:id], fixed_params: params,
                   description: [metadata[:description], summary].compact.join(': '))
  end

  def fixed_params_tool_class(tool_id)
    tool_class = self.class.resolve_tool_class(tool_id)
    tool_class if tool_class.is_a?(Class) && tool_class < Captain::Tools::BuiltInActionTool
  end

  def resolve_tool_instance(tool_metadata)
    tool_id = tool_metadata[:id]

    if tool_metadata[:custom]
      custom_tool = Captain::CustomTool.find_by(slug: tool_id, account_id: account_id, enabled: true)
      custom_tool&.tool(assistant)
    elsif tool_metadata[:mcp]
      assistant.account.captain_mcp_servers.lazy.filter_map { |server| server.agent_tool(tool_id, assistant) }.first
    else
      built_in_tool_instance(tool_metadata)
    end
  end

  def built_in_tool_instance(tool_metadata)
    fixed_params = tool_metadata[:fixed_params]
    return fixed_params_tool_class(tool_metadata[:tool_id])&.new(assistant, fixed_params: fixed_params) if fixed_params

    self.class.resolve_tool_class(tool_metadata[:id])&.new(assistant)
  end

  # Validates that all tool references in the instruction are valid.
  # Parses the instruction for tool references and checks if they exist
  # in the available tools configuration.
  #
  # @return [void]
  # @api private
  # @example Valid instruction
  #   scenario.instruction = "Use [Add Contact Note](tool://add_contact_note) to document"
  #   scenario.valid? # => true
  #
  # @example Invalid instruction
  #   scenario.instruction = "Use [Invalid Tool](tool://invalid_tool) to process"
  #   scenario.valid? # => false
  #   scenario.errors[:instruction] # => ["contains invalid tools: invalid_tool"]
  def validate_instruction_tools
    return if instruction.blank?

    tool_ids = extract_tool_ids_from_text(instruction)
    return if tool_ids.empty?

    invalid_tools = tool_ids - assistant.known_tool_ids

    errors.add(:instruction, "contains invalid tools: #{invalid_tools.join(', ')}") if invalid_tools.any?
    validate_fixed_tool_params(tool_ids - invalid_tools)
  end

  # Built-in actions need their fixed parameters to point at things that exist: an attribute, a team, a template.
  def validate_fixed_tool_params(tool_ids)
    extract_tool_references(instruction).each do |reference|
      next unless tool_ids.include?(reference[:id])

      tool_class = fixed_params_tool_class(reference[:id])
      next if tool_class.nil? && reference[:params].blank?
      next errors.add(:instruction, "#{reference[:id]} doesn't take fixed parameters") if tool_class.nil?

      tool_class.fixed_param_errors(assistant, reference[:params]).each { |message| errors.add(:instruction, message) }
    end
  end

  # Resolves tool references from the instruction text into the tools field.
  # Parses the instruction for tool references and materializes them as
  # tool IDs stored in the tools JSONB field.
  #
  # @return [void]
  # @api private
  # @example
  #   scenario.instruction = "First [@Add Private Note](tool://add_private_note) then [@Update Priority](tool://update_priority)"
  #   scenario.save!
  #   scenario.tools # => ["add_private_note", "update_priority"]
  #
  #   scenario.instruction = "No tools mentioned here"
  #   scenario.save!
  #   scenario.tools # => nil
  def resolve_tool_references
    return if instruction.blank?

    tool_ids = extract_tool_ids_from_text(instruction)
    self.tools = tool_ids.presence
  end
end

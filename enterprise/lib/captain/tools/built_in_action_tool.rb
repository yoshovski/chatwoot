# Base for the built-in actions a scenario names with fixed parameters, such as
# [Save Company size](tool://update_contact_attribute?key=company_size).
#
# Fixed parameters come from the reference, never from the model: they are not in the tool's schema, so the AI fills
# only the open values. Each reference becomes its own tool, named after its fixed values so two references to the
# same action (two attributes, say) don't collide.
class Captain::Tools::BuiltInActionTool < Captain::Tools::BasePublicTool
  TOOL_NAME_PREFIX = 'captain--tools--'.freeze
  # OpenAI allows 64 characters; keep the same margin as scenario handoff names.
  MAX_TOOL_NAME_LENGTH = 60
  DIGEST_LENGTH = 6

  class << self
    def tool_id = name.demodulize.delete_suffix('Tool').underscore

    def fixed_param(key, required: true)
      fixed_params_spec[key.to_s] = { required: required }
    end

    def fixed_params_spec
      @fixed_params_spec ||= {}
    end

    # Validation messages for a reference's fixed parameters; empty when the reference is usable.
    def fixed_param_errors(assistant, params)
      params = params.to_h.stringify_keys
      unknown = params.keys - fixed_params_spec.keys
      return ["#{tool_id} has no parameter #{unknown.join(', ')}"] if unknown.any?

      missing = fixed_params_spec.select { |key, spec| spec[:required] && params[key].blank? }.keys
      return ["#{tool_id} needs #{missing.join(', ')}"] if missing.any?

      Array(validate_fixed_params(assistant, params))
    end

    # The name the instruction and the prompt use for one reference, e.g. update_contact_attribute__company_size.
    def reference_key(params)
      return tool_id if params.blank?

      sorted = params.to_h.stringify_keys.sort
      slug = sorted.map { |_key, value| value.to_s }.join('_').parameterize(separator: '_')
      budget = MAX_TOOL_NAME_LENGTH - TOOL_NAME_PREFIX.length - tool_id.length - 2
      return "#{tool_id}__#{slug}" if slug.length <= budget

      # Long values (a follow-up's instructions) keep a readable start plus a digest of the whole reference.
      digest = Digest::SHA256.hexdigest(sorted.to_s).first(DIGEST_LENGTH)
      "#{tool_id}__#{slug.first(budget - DIGEST_LENGTH - 1).sub(/_+\z/, '')}_#{digest}"
    end

    # A short phrase for the instruction and prompt ("saves the contact's Company size"). Subclasses override.
    def fixed_summary(_assistant, _params) = nil

    private

    # Subclasses check their fixed values against the account (attribute exists, team exists, ...).
    def validate_fixed_params(_assistant, _params) = []
  end

  def initialize(assistant, fixed_params: {})
    @fixed_params = fixed_params.to_h.stringify_keys
    super(assistant)
  end

  def name
    return super if @fixed_params.blank?

    "#{TOOL_NAME_PREFIX}#{self.class.reference_key(@fixed_params)}"
  end

  def description
    summary = self.class.fixed_summary(@assistant, @fixed_params) if @fixed_params.present?
    [self.class.description, summary&.upcase_first].compact.join('. ')
  end

  private

  def fixed(key) = @fixed_params[key.to_s]

  # A reference without its fixed parameters (or one whose attribute/team was deleted) can't run.
  def fixed_params_error(state)
    errors = self.class.fixed_param_errors(@assistant, @fixed_params)
    failure_result("This action isn't set up correctly: #{errors.join('; ')}", state) if errors.any?
  end
end

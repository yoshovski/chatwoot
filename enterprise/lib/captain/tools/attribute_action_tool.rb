# Shared logic of update_contact_attribute and update_conversation_attribute: the reference fixes which custom
# attribute (key); the AI fills only the value, which is checked against the attribute's type.
class Captain::Tools::AttributeActionTool < Captain::Tools::BuiltInActionTool
  fixed_param :key

  class << self
    def attribute_model = raise(NotImplementedError)

    def definition(assistant, key)
      assistant.account.custom_attribute_definitions.find_by(attribute_model: attribute_model, attribute_key: key.to_s)
    end

    private

    def validate_fixed_params(assistant, params)
      key = params['key']
      return ["#{tool_id} can't change #{key}: the lead tools own name, email and phone"] if protected_key?(key)
      return ["no #{attribute_model.humanize(capitalize: false)} #{key}"] unless definition(assistant, key)

      []
    end

    def protected_key?(key) = Captain::Tools::AttributeValue::PROTECTED_KEYS.include?(key.to_s.downcase)
  end

  def perform(tool_context, value:)
    state = tool_context.state
    error = fixed_params_error(state)
    return error if error

    definition = self.class.definition(@assistant, fixed(:key))
    cast, cast_error = Captain::Tools::AttributeValue.cast(definition, value)
    return failure_result("Not saved. #{cast_error}. Ask the visitor again if needed.", state) if cast_error

    record = target(state)
    return failure_result("#{self.class.attribute_model.humanize} not found", state) unless record
    return "Would save #{definition.attribute_display_name} = #{cast} (preview, nothing saved)." if state[:source] == 'playground'

    record.update!(custom_attributes: (record.custom_attributes || {}).merge(definition.attribute_key => cast))
    log_tool_usage('updated_attribute', record_id: record.id, key: definition.attribute_key)
    "Saved #{definition.attribute_display_name}: #{cast}"
  end
end

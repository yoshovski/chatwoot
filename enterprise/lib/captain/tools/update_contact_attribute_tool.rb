class Captain::Tools::UpdateContactAttributeTool < Captain::Tools::AttributeActionTool
  description "Saves a value on the visitor's contact profile"
  param :value, type: 'string', desc: 'The value to save, exactly as the visitor gave it (numbers as digits, dates as YYYY-MM-DD)'

  def self.attribute_model = 'contact_attribute'

  def self.fixed_summary(assistant, params)
    "saves the contact's #{definition(assistant, params['key'])&.attribute_display_name || params['key']}"
  end

  private

  def target(state) = find_contact(state)
end

class Captain::Tools::UpdateConversationAttributeTool < Captain::Tools::AttributeActionTool
  description 'Saves a value on this conversation'
  param :value, type: 'string', desc: 'The value to save (numbers as digits, dates as YYYY-MM-DD)'

  def self.attribute_model = 'conversation_attribute'

  def self.fixed_summary(assistant, params)
    "saves the conversation's #{definition(assistant, params['key'])&.attribute_display_name || params['key']}"
  end

  private

  def target(state) = find_conversation(state)
end

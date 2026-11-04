# What a scenario can name with fixed values, for the scenario builder and "Describe an action": the built-in
# actions and the account's attributes, teams and the agent's email templates.
class Captain::Llm::ActionCatalog
  ATTRIBUTE_TOOLS = {
    'update_contact_attribute' => 'contact_attribute',
    'update_conversation_attribute' => 'conversation_attribute'
  }.freeze
  ATTRIBUTE_TYPES = %w[text number link date list checkbox].freeze
  LIST_LIMIT = 50

  def initialize(assistant)
    @assistant = assistant
    @account = assistant.account
  end

  def actions
    Captain::Assistant.built_in_agent_tools.select { |tool| tool[:built_in_action] }.map do |tool|
      { 'id' => tool[:id], 'title' => tool[:title], 'description' => tool[:description],
        'fixed_params' => tool[:fixed_params].pluck(:key) }
    end
  end

  def custom_actions
    @account.captain_custom_tools.enabled.limit(LIST_LIMIT).map { |tool| { 'id' => tool.slug, 'title' => tool.title } }
  end

  def attributes(model)
    @account.custom_attribute_definitions.where(attribute_model: model).limit(LIST_LIMIT)
            .map { |definition| { 'key' => definition.attribute_key, 'label' => definition.attribute_display_name } }
  end

  def teams = @account.teams.limit(LIST_LIMIT).map { |team| { 'id' => team.id, 'name' => team.name } }

  def templates
    (@assistant.config['email_templates'] || {}).map { |key, template| { 'key' => key, 'name' => template['name'].presence || key } }
  end

  def prompt_context
    {
      'actions' => actions, 'contact_attributes' => attributes('contact_attribute'),
      'conversation_attributes' => attributes('conversation_attribute'), 'teams' => teams, 'templates' => templates
    }
  end
end

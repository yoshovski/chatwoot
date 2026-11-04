# Email templates an AI agent's built-in actions send: config['email_templates'] = { key => { name, subject, body } }.
# Subject and body are Liquid with contact.*, conversation.* and agent.name (plus summary for team emails).
class Captain::EmailTemplates
  MAX_TEMPLATES = 10
  NAME_LIMIT = 80
  SUBJECT_LIMIT = 200
  BODY_LIMIT = 5000
  KEY_FORMAT = /\A[a-z0-9_]{1,40}\z/

  def self.errors(templates)
    return [] if templates.blank?
    return ['must be an object'] unless templates.is_a?(Hash)
    return ["can have at most #{MAX_TEMPLATES} templates"] if templates.size > MAX_TEMPLATES

    templates.flat_map { |key, template| template_errors(key.to_s, template) }
  end

  def self.template_errors(key, template)
    return ["#{key}: key may only use a-z, 0-9 and _"] unless KEY_FORMAT.match?(key)
    return ["#{key}: must be an object"] unless template.is_a?(Hash)

    template = template.stringify_keys
    errors = %w[subject body].filter_map { |field| "#{key}: #{field} is required" if template[field].blank? }
    errors += { 'name' => NAME_LIMIT, 'subject' => SUBJECT_LIMIT, 'body' => BODY_LIMIT }.filter_map do |field, limit|
      "#{key}: #{field} is too long" if template[field].to_s.length > limit
    end
    errors + liquid_errors(key, template)
  end

  def self.liquid_errors(key, template)
    %w[subject body].each { |field| Liquid::Template.parse(template[field].to_s) }
    []
  rescue Liquid::SyntaxError => e
    ["#{key}: #{e.message}"]
  end

  def initialize(assistant)
    @assistant = assistant
    @templates = (assistant.config['email_templates'].presence || {}).transform_keys(&:to_s)
  end

  def find(key) = @templates[key.to_s]

  def name(key) = find(key)&.dig('name').presence || key.to_s.humanize

  # Returns { subject:, body: } with the conversation's values filled in.
  def render(key, conversation, locals = {})
    template = find(key) || raise(ArgumentError, "Unknown email template #{key}")
    assigns = {
      'contact' => ContactDrop.new(conversation.contact),
      'conversation' => ConversationDrop.new(conversation),
      'agent' => { 'name' => @assistant.name }
    }.merge(locals.stringify_keys)
    { subject: render_text(template['subject'], assigns).squish, body: render_text(template['body'], assigns).strip }
  end

  private

  def render_text(text, assigns) = Liquid::Template.parse(text.to_s).render(assigns)
end

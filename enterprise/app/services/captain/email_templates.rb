# Email templates an AI agent's built-in actions send: config['email_templates'] = { key => { name, subject, body, format } }.
# Subject and body are Liquid with contact.*, conversation.*, agent.name, business.name, inbox.name, assignee.name,
# conversation_url and today (plus summary for team emails). format 'html' sends an HTML body with a text fallback;
# values are HTML-escaped and the result is sanitized.
class Captain::EmailTemplates
  MAX_TEMPLATES = 10
  NAME_LIMIT = 80
  SUBJECT_LIMIT = 200
  BODY_LIMIT = 5000
  HTML_BODY_LIMIT = 20_000
  FORMATS = %w[text html].freeze
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
    errors += format_errors(key, template)
    errors += { 'name' => NAME_LIMIT, 'subject' => SUBJECT_LIMIT, 'body' => body_limit(template) }.filter_map do |field, limit|
      "#{key}: #{field} is too long" if template[field].to_s.length > limit
    end
    errors + liquid_errors(key, template)
  end

  def self.format_errors(key, template)
    FORMATS.include?(template['format'] || 'text') ? [] : ["#{key}: format must be text or html"]
  end

  def self.body_limit(template) = template['format'] == 'html' ? HTML_BODY_LIMIT : BODY_LIMIT

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

  # Returns { subject:, body:, html: } with the conversation's values filled in. body is always plain text (also used
  # for follow-up chat messages); html is set only for HTML templates.
  def render(key, conversation, locals = {})
    template = find(key) || raise(ArgumentError, "Unknown email template #{key}")
    assigns = assigns_for(conversation).merge(locals.stringify_keys)
    subject = render_text(template['subject'], assigns).squish
    return { subject: subject, body: render_text(template['body'], assigns).strip, html: nil } unless template['format'] == 'html'

    html = render_html(template['body'], assigns)
    { subject: subject, body: html_to_text(html), html: html }
  end

  private

  def assigns_for(conversation)
    {
      'contact' => ContactDrop.new(conversation.contact),
      'conversation' => ConversationDrop.new(conversation),
      'agent' => { 'name' => @assistant.name },
      'business' => { 'name' => conversation.account.name },
      'inbox' => { 'name' => conversation.inbox.name },
      'assignee' => { 'name' => conversation.assignee&.available_name.to_s },
      'conversation_url' => conversation_url(conversation),
      'today' => I18n.l(Date.current, format: :long)
    }
  end

  def conversation_url(conversation)
    "#{ENV.fetch('FRONTEND_URL', '').chomp('/')}/app/accounts/#{conversation.account_id}/conversations/#{conversation.display_id}"
  end

  def render_text(text, assigns) = Liquid::Template.parse(text.to_s).render(assigns)

  def render_html(text, assigns)
    rendered = Liquid::Template.parse(text.to_s).render(assigns, global_filter: ->(value) { CGI.escapeHTML(value.to_s) })
    Loofah.fragment(rendered).scrub!(:prune).to_s.strip
  end

  def html_to_text(html)
    doc = Nokogiri::HTML.fragment(html.gsub(%r{<br\s*/?>}i, "\n").gsub(%r{</(p|div|h[1-6]|li|tr)>}i, "\n"))
    doc.text.gsub(/\n{3,}/, "\n\n").strip
  end
end

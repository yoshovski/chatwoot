# Turns OpenAPI definitions embedded in documentation markdown into the reference a support agent reads:
# one section per operation with its endpoint, authentication, parameter and field tables and a small
# example request. Raw spec JSON would be chunked into fragments like `"type": "string",` that match no question,
# and per-language code samples are generated from the same definition, so neither is kept.
class Captain::Knowledge::OpenApiMarkdown
  # A fenced JSON or YAML block, with the "OpenAPI definition" heading documentation sites put above it.
  FENCE = /^(?:\#{1,6}[ \t]+[^\n]*openapi[^\n]*\n+)?(`{3,}|~{3,})[ \t]*(json|ya?ml)[ \t]*\n(.*?)\n\1[ \t]*$/mi
  METHODS = %w[get put post delete patch head options trace].freeze
  # Sent by every client; listing them answers nothing.
  TRANSPORT_HEADERS = %w[accept content-type].freeze
  MAX_DEPTH = 4
  MAX_ROWS = 60
  EXAMPLE_MAX_LENGTH = 1500

  def self.convert(markdown)
    markdown.gsub(FENCE) do
      match = Regexp.last_match
      spec = parse(match[2], match[3])
      spec ? new(spec).to_s : match[0]
    end
  end

  def self.parse(language, text)
    spec = language.casecmp?('json') ? JSON.parse(text) : YAML.safe_load(text)
    spec if spec.is_a?(Hash) && (spec['openapi'] || spec['swagger']) && spec['paths'].is_a?(Hash)
  rescue JSON::ParserError, Psych::Exception
    nil
  end

  def initialize(spec)
    @spec = spec
  end

  def to_s
    @spec['paths'].flat_map do |path, item|
      item = resolve(item)
      item.slice(*METHODS).map { |method, operation| operation_section(path, method, resolve(operation), item['parameters']) }
    end.join("\n\n")
  end

  private

  def operation_section(path, method, operation, shared_parameters)
    summary = operation['summary'].to_s.squish.presence
    [
      "## #{method.upcase} #{path}#{": #{summary}" if summary}",
      overview(path, method, operation),
      # Headings inside the description belong under this operation's heading.
      operation['description'].to_s.strip.gsub(/^(\#{1,6})(?=[ \t])/) { '#' * [Regexp.last_match(1).length + 2, 6].min }.presence,
      parameters_section(Array(shared_parameters) + Array(operation['parameters'])),
      request_section(resolve(operation['requestBody'])),
      *responses_section(operation['responses'])
    ].compact.join("\n\n")
  end

  def overview(path, method, operation)
    server = Array(operation['servers'] || @spec['servers']).first&.dig('url')
    endpoint = server ? "#{server.delete_suffix('/')}/#{path.delete_prefix('/')}" : path
    auth = authentication(operation['security'] || @spec['security'])
    ["Endpoint: `#{method.upcase} #{endpoint}`.", ("Authentication: #{auth}." if auth)].compact.join(' ')
  end

  def authentication(requirements)
    schemes = @spec.dig('components', 'securitySchemes') || @spec['securityDefinitions'] || {}
    names = Array(requirements).flat_map { |requirement| requirement.is_a?(Hash) ? requirement.keys : [] }.uniq
    names.filter_map { |name| scheme_text(resolve(schemes[name])) }.join(' or ').presence
  end

  def scheme_text(scheme)
    case scheme['type']
    when 'apiKey' then "`#{scheme['name']}` #{scheme['in']}"
    when 'http' then "HTTP #{scheme['scheme']}"
    when 'oauth2' then 'OAuth 2.0'
    when 'openIdConnect' then 'OpenID Connect'
    end
  end

  def parameters_section(parameters)
    rows = parameters.map { |parameter| resolve(parameter) }.filter_map do |parameter|
      next if parameter['in'] == 'header' && TRANSPORT_HEADERS.include?(parameter['name'].to_s.downcase)

      schema = resolve(parameter['schema'] || parameter)
      [parameter['name'], parameter['in'], type(schema), parameter['required'] ? 'yes' : 'no',
       details(parameter['description'], schema)]
    end
    table('### Parameters', %w[Parameter In Type Required Description], rows)
  end

  def request_section(body)
    media_type, content = media(body['content'])
    return unless content

    schema = resolve(content['schema'])
    rows = fields(schema).map { |name, field, required| [name, type(field), required ? 'yes' : 'no', details(field['description'], field)] }
    [table("### Request body (#{media_type})", %w[Field Type Required Description], rows), example(content, schema)].compact.join("\n\n").presence
  end

  def responses_section(responses)
    resolve(responses).map do |status, response|
      response = resolve(response)
      _, content = media(response['content'])
      rows = fields(resolve(content&.dig('schema') || response['schema'])).map { |name, field| [name, type(field), details(field['description'], field)] }
      description = response['description'].to_s.squish
      heading = "### Response #{status}#{": #{description}" if description.present? && description != status.to_s}"
      table(heading, %w[Field Type Description], rows) || heading
    end
  end

  def media(content)
    return unless content.is_a?(Hash) && content.any?

    content.find { |media_type, _| media_type.include?('json') } || content.first
  end

  def example(content, schema)
    value = content['example'] || resolve(content['examples']&.values&.first)&.dig('value') || schema['example']
    return if value.nil?

    json = JSON.pretty_generate(value)
    "Example request body:\n\n```json\n#{json}\n```" if json.length <= EXAMPLE_MAX_LENGTH
  end

  # [dotted name, schema, required] for every property, nested objects and array items included.
  def fields(schema, prefix = '', depth = 0, rows = [])
    schema = resolve(schema['items']) if schema['type'] == 'array' && prefix.empty?
    required = required_names(schema)
    properties(schema).each do |name, property|
      return rows if rows.size >= MAX_ROWS

      property = resolve(property)
      rows << ["#{prefix}#{name}", property, required.include?(name)]
      nested = property['type'] == 'array' ? resolve(property['items']) : property
      fields(nested, "#{prefix}#{name}#{'[]' if property['type'] == 'array'}.", depth + 1, rows) if depth < MAX_DEPTH
    end
    rows
  end

  # Composed schemas list their fields in their parts; variants of oneOf/anyOf are listed together.
  def properties(schema)
    parts = [schema, *schema.values_at('allOf', 'oneOf', 'anyOf').compact.flatten.map { |part| resolve(part) }]
    parts.map { |part| part['properties'].is_a?(Hash) ? part['properties'] : {} }.reduce({}, :merge)
  end

  def required_names(schema)
    [schema, *Array(schema['allOf']).map { |part| resolve(part) }].flat_map { |part| Array(part['required']) }
  end

  def type(schema)
    type = Array(schema['type']).join(' or ').presence || ('object' if properties(schema).any?)
    type = "array of #{type(resolve(schema['items'])) || 'values'}" if type == 'array'
    [type, ("(#{schema['format']})" if schema['format'])].compact.join(' ').presence
  end

  # Response fields are often documented only by an example value.
  def details(description, schema)
    description = description.to_s.squish.presence
    choices = "One of: #{schema['enum'].join(', ')}." if schema['enum'].is_a?(Array)
    example = "Example: #{schema['example']}." if description.nil? && schema['example'].then { |value| value.is_a?(String) || value.is_a?(Numeric) }
    [description, choices, example].compact.join(' ')
  end

  def table(heading, columns, rows)
    return if rows.empty?

    lines = [columns, columns.map { '---' }, *rows].map { |cells| "| #{cells.map { |cell| cell.to_s.squish.gsub('|', '\|') }.join(' | ')} |" }
    "#{heading}\n\n#{lines.join("\n")}"
  end

  # Local `#/…` references only; unresolvable ones read as an empty schema.
  def resolve(node, hops = 0)
    return node.is_a?(Hash) ? node : {} unless node.is_a?(Hash) && node['$ref'].is_a?(String) && hops < 10

    path = node['$ref'].delete_prefix('#/').split('/').map { |part| part.gsub('~1', '/').gsub('~0', '~') }
    target = node['$ref'].start_with?('#/') ? @spec.dig(*path) : nil
    resolve(target, hops + 1)
  end
end

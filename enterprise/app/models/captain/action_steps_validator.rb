# Checks a custom tool's steps, outputs and messages: shapes, limits, safe URLs on every request step, and that each
# template only reads the tool's params, outputs of earlier steps and the allowed contact fields.
class Captain::ActionStepsValidator < ActiveModel::Validator
  STEP_TYPES = %w[request verify].freeze
  REQUEST_METHODS = %w[GET POST PUT PATCH DELETE].freeze
  BODY_TYPES = %w[json text].freeze
  COMPARISONS = %w[exact case_insensitive email phone].freeze
  OUTPUT_TYPES = %w[string number boolean array object].freeze
  MESSAGE_KEYS = %w[confirm_prompt success failure].freeze
  CONTACT_FIELDS = %w[email phone_number name].freeze
  KEY_FORMAT = /\A[a-z0-9_]{1,32}\z/
  HEADER_NAME_FORMAT = /\A[A-Za-z0-9-]+\z/
  MAX_STEPS = { 'request' => 3, 'verify' => 2 }.freeze
  KEY_ERROR = 'must use a-z, 0-9 and _ (32 characters at most)'.freeze

  def validate(record)
    @record = record
    validate_steps
    validate_outputs
    validate_messages
    validate_template_references if errors.empty? && record.action_templates_changed?
  end

  private

  attr_reader :record

  delegate :errors, :steps, :outputs, :messages, to: :record

  def validate_steps
    return errors.add(:steps, 'must include a request step') if record.request_steps.empty?

    MAX_STEPS.each do |type, max|
      errors.add(:steps, "can have at most #{max} #{type} steps") if steps.count { |step| step['type'] == type } > max
    end
    steps.each { |step| validate_step(step) }
    add_duplicate_error(:steps, steps.pluck('key'))
  end

  def validate_step(step)
    return errors.add(:steps, "key #{step['key'].inspect} #{KEY_ERROR}") unless KEY_FORMAT.match?(step['key'].to_s)

    attribute = :"steps.#{step['key']}"
    return errors.add(attribute, "has an unknown type #{step['type'].inspect}") unless STEP_TYPES.include?(step['type'])

    step['type'] == 'request' ? validate_request_step(step, attribute) : validate_verify_step(step, attribute)
  end

  def validate_request_step(step, attribute)
    errors.add(attribute, "method must be one of #{REQUEST_METHODS.join(', ')}") unless REQUEST_METHODS.include?(step['method'])
    errors.add(attribute, "body type must be one of #{BODY_TYPES.join(', ')}") unless BODY_TYPES.include?(step['body_type'] || 'json')
    errors.add(attribute, 'headers need a name made of letters, digits and dashes') unless valid_headers?(step['headers'] || [])
    validate_request_url(step['url'], attribute)
  end

  def validate_request_url(url, attribute)
    return errors.add(attribute, 'URL is required') if url.blank?

    record.send(:safe_endpoint_errors, url).each { |message| errors.add(attribute, "URL #{message}") }
  end

  def valid_headers?(headers)
    headers.is_a?(Array) && headers.all? { |header| header.is_a?(Hash) && HEADER_NAME_FORMAT.match?(header['name'].to_s) }
  end

  def validate_verify_step(step, attribute)
    errors.add(attribute, 'needs a value on both sides') if step['left'].blank? || step['right'].blank?
    errors.add(attribute, "comparison must be one of #{COMPARISONS.join(', ')}") unless COMPARISONS.include?(step['compare'])
  end

  def validate_outputs
    request_keys = record.request_steps.pluck('key')
    outputs.each do |output|
      next errors.add(:outputs, "key #{output['key'].inspect} #{KEY_ERROR}") unless KEY_FORMAT.match?(output['key'].to_s)

      validate_output(output, request_keys, :"outputs.#{output['key']}")
    end
    add_duplicate_error(:outputs, outputs.pluck('key'))
  end

  def validate_output(output, request_keys, attribute)
    errors.add(attribute, 'must come from a request step') unless request_keys.include?(output['step'])
    errors.add(attribute, 'needs a response path') if output['path'].blank?
    errors.add(attribute, "type must be one of #{OUTPUT_TYPES.join(', ')}") if output['type'].present? && OUTPUT_TYPES.exclude?(output['type'])
  end

  def validate_messages
    errors.add(:messages, "only allows #{MESSAGE_KEYS.join(', ')}") if (messages.keys - MESSAGE_KEYS).any?
  end

  def add_duplicate_error(attribute, keys)
    duplicates = keys.tally.select { |_key, count| count > 1 }.keys
    errors.add(attribute, "have duplicate keys: #{duplicates.join(', ')}") if duplicates.any?
  end

  def validate_template_references
    steps.each_with_index do |step, index|
      allowed = outputs_available_before(index)
      step_templates(step).each { |template| check_template(template, allowed, :"steps.#{step['key']}") }
    end
    all_outputs = outputs.pluck('key')
    messages.each { |key, template| check_template(template.to_s, all_outputs, :"messages.#{key}") }
  end

  def outputs_available_before(index)
    earlier_steps = steps.first(index).pluck('key')
    outputs.select { |output| earlier_steps.include?(output['step']) }.pluck('key')
  end

  def step_templates(step)
    return [step['left'], step['right']].map(&:to_s) if step['type'] == 'verify'

    [step['url'].to_s, step['body'].to_s, *Array(step['headers']).map { |header| header['value'].to_s }]
  end

  def check_template(template, output_keys, attribute)
    return if template.exclude?('{{') && template.exclude?('{%')

    references = Captain::Tools::TemplateReferences.new(template)
    unknown = references.unknown(params: record.param_schema.pluck('name'), outputs: output_keys, contact_fields: CONTACT_FIELDS)
    errors.add(attribute, "uses unknown variables: #{unknown.join(', ')}") if unknown.any?
  rescue Liquid::SyntaxError => e
    errors.add(attribute, "has a template error: #{e.message}")
  end
end

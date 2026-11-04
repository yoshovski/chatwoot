# Checks a value the AI wants to save against a custom attribute definition and returns it in the stored form.
module Captain::Tools::AttributeValue
  # Name, email and phone belong to the lead tools; never overwrite them through an attribute action.
  PROTECTED_KEYS = %w[name email phone_number phone].freeze
  TEXT_LIMIT = 1000
  TRUE_VALUES = %w[true yes y 1 on].freeze
  FALSE_VALUES = %w[false no n 0 off].freeze

  module_function

  # Returns [value, error]; error is a message for the model when the value doesn't fit.
  def cast(definition, raw)
    raw = raw.to_s.strip
    return [nil, 'A value is required'] if raw.blank?

    value, error = cast_by_type(definition, raw)
    return [nil, error] if error
    return [nil, "The value doesn't match the expected format: #{definition.regex_cue.presence || raw}"] unless regex_ok?(definition, raw)

    [value, nil]
  end

  def cast_by_type(definition, raw)
    case definition.attribute_display_type
    when 'number', 'currency', 'percent' then number(raw)
    when 'checkbox' then checkbox(raw)
    when 'date' then date(raw)
    when 'link' then link(raw)
    when 'list' then list_option(definition, raw)
    else raw.length > TEXT_LIMIT ? [nil, "Keep it under #{TEXT_LIMIT} characters"] : [raw, nil]
    end
  end

  def number(raw)
    value = BigDecimal(raw.delete(',').delete_suffix('%'))
    [value.frac.zero? ? value.to_i : value.to_f, nil]
  rescue ArgumentError
    [nil, 'Expected a number']
  end

  def checkbox(raw)
    return [true, nil] if TRUE_VALUES.include?(raw.downcase)
    return [false, nil] if FALSE_VALUES.include?(raw.downcase)

    [nil, 'Expected yes or no']
  end

  def date(raw)
    [Date.iso8601(raw).iso8601, nil]
  rescue Date::Error
    [nil, 'Expected a date as YYYY-MM-DD']
  end

  def link(raw)
    uri = URI.parse(raw)
    uri.is_a?(URI::HTTP) && uri.host.present? ? [raw, nil] : [nil, 'Expected a full http(s) link']
  rescue URI::InvalidURIError
    [nil, 'Expected a full http(s) link']
  end

  def list_option(definition, raw)
    options = Array(definition.attribute_values)
    option = options.find { |item| item.to_s.casecmp?(raw) }
    option ? [option, nil] : [nil, "Expected one of: #{options.join(', ')}"]
  end

  def regex_ok?(definition, raw)
    return true if definition.regex_pattern.blank? || definition.attribute_display_type != 'text'

    Regexp.new(definition.regex_pattern).match?(raw)
  rescue RegexpError
    true
  end
end

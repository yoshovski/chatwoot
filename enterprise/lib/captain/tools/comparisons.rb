# How a check step compares its value with the expected one. Text comparisons ignore case except "exact" and
# "not_equal"; "one_of" takes a comma-separated list; "phone" compares the last 9 digits. Every comparison fails on
# a blank value, so a missing field never passes a check.
module Captain::Tools::Comparisons
  PHONE_DIGITS_COMPARED = 9
  PHONE_DIGITS = ->(value) { value.gsub(/\D/, '').last(PHONE_DIGITS_COMPARED) }
  NUMBER = ->(value) { Float(value, exception: false) }
  LIST = ->(value) { value.split(',').map { |item| item.strip.downcase }.compact_blank }
  COMPARATORS = {
    'exact' => ->(left, right) { left == right },
    'not_equal' => ->(left, right) { left != right },
    'case_insensitive' => ->(left, right) { left.casecmp?(right) },
    'contains' => ->(left, right) { left.downcase.include?(right.downcase) },
    'not_contains' => ->(left, right) { left.downcase.exclude?(right.downcase) },
    'starts_with' => ->(left, right) { left.downcase.start_with?(right.downcase) },
    'one_of' => ->(left, right) { LIST.call(right).include?(left.downcase) },
    'not_one_of' => ->(left, right) { LIST.call(right).exclude?(left.downcase) },
    'greater_than' => ->(left, right) { NUMBER.call(left) && NUMBER.call(right) && NUMBER.call(left) > NUMBER.call(right) },
    'less_than' => ->(left, right) { NUMBER.call(left) && NUMBER.call(right) && NUMBER.call(left) < NUMBER.call(right) },
    'present' => ->(_left, _right) { true },
    'email' => ->(left, right) { left.downcase == right.downcase },
    'phone' => ->(left, right) { PHONE_DIGITS.call(left).present? && PHONE_DIGITS.call(left) == PHONE_DIGITS.call(right) }
  }.freeze
  NAMES = COMPARATORS.keys.freeze
  # Comparisons that only look at the value and have no expected one.
  UNARY = %w[present].freeze

  def self.match?(compare, left, right)
    return false if left.blank? || (right.blank? && UNARY.exclude?(compare))

    COMPARATORS.fetch(compare).call(left, right).present?
  end
end

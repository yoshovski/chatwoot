# Apply persisted rule audiences before any model sees the instructions.
class Captain::SegmentRules
  FIELDS = %w[response_guidelines guardrails].freeze

  def initialize(assistant, contact)
    @assistant = assistant
    @contact = contact
  end

  def apply(context)
    audiences = @assistant.config['rule_segments']
    return context if audiences.blank?

    context = context.dup
    segments = Contacts::Segments.new(@assistant.account)
    FIELDS.each do |field|
      rules = audiences.fetch(field, {})
      context[field.to_sym] = Array(context[field.to_sym]).select do |text|
        reference = rules[text]
        reference.blank? || (@contact && segments.matches?(reference, @contact))
      end
    end
    context
  end
end

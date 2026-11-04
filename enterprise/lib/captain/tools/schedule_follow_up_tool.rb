# Schedules one follow-up (a chat message or an email) after a quiet period. It's cancelled when the visitor writes,
# a human replies, or the conversation is resolved or handed off.
class Captain::Tools::ScheduleFollowUpTool < Captain::Tools::BuiltInActionTool
  MIN_MINUTES = 15
  MAX_MINUTES = 7.days.in_minutes.to_i
  KINDS = %w[message email].freeze
  INSTRUCTIONS_LIMIT = 500

  description 'Schedules a follow-up if the visitor goes quiet'
  fixed_param :after
  fixed_param :kind
  fixed_param :template, required: false
  fixed_param :instructions, required: false

  class << self
    include Captain::Tools::TemplateActionHelpers

    def fixed_summary(_assistant, params)
      "follows up by #{params['kind'] == 'email' ? 'email' : 'message'} after #{duration(params['after'].to_i)} of quiet"
    end

    def duration(minutes)
      return "#{minutes / 1440} day#{'s' if minutes >= 2880}" if (minutes % 1440).zero?
      return "#{minutes / 60} hour#{'s' if minutes >= 120}" if (minutes % 60).zero?

      "#{minutes} minutes"
    end

    private

    def validate_fixed_params(assistant, params)
      errors = []
      errors << "after must be #{MIN_MINUTES}-#{MAX_MINUTES} minutes" unless params['after'].to_s.match?(/\A\d+\z/) &&
                                                                             params['after'].to_i.between?(MIN_MINUTES, MAX_MINUTES)
      errors << 'kind must be message or email' unless KINDS.include?(params['kind'])
      errors + content_errors(assistant, params)
    end

    def content_errors(assistant, params)
      return template_errors(assistant, params['template']) if params['template'].present?
      return ['an email follow-up needs a template'] if params['kind'] == 'email'
      return ['a follow-up needs a template or instructions'] if params['instructions'].blank?

      params['instructions'].length > INSTRUCTIONS_LIMIT ? ["instructions must be under #{INSTRUCTIONS_LIMIT} characters"] : []
    end
  end

  def perform(tool_context)
    state = tool_context.state
    error = fixed_params_error(state)
    return error if error

    minutes = fixed(:after).to_i
    return "Would follow up after #{self.class.duration(minutes)} (preview)." if state[:source] == 'playground'

    conversation = find_conversation(state)
    return failure_result('Conversation not found', state) unless conversation

    schedule(conversation, minutes, state)
  rescue ActiveRecord::RecordInvalid => e
    failure_result("No follow-up was scheduled: #{e.record.errors.full_messages.to_sentence}.", state)
  end

  private

  def email? = fixed(:kind) == 'email'

  def schedule(conversation, minutes, state)
    return failure_result("No email address for the visitor yet. Don't promise an email.", state) if email? && conversation.contact&.email.blank?

    reference = self.class.reference_key(@fixed_params)
    Captain::ScheduledActions.schedule!(
      conversation: conversation, assistant: @assistant, kind: "follow_up_#{fixed(:kind)}", at: minutes.minutes.from_now,
      payload: { 'template' => fixed(:template), 'instructions' => fixed(:instructions), 'tool' => reference }.compact, dedupe_key: reference
    )
    log_tool_usage('scheduled_follow_up', conversation_id: conversation.id, after: minutes, kind: fixed(:kind))
    "A follow-up is scheduled after #{self.class.duration(minutes)} of quiet; it's cancelled if the visitor replies. " \
      "Don't mention it unless it helps (for example: \"I'll check back later\")."
  end
end

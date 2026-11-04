class Captain::Leads::QuestionBudget
  ATTRIBUTE_KEY = 'business_lead_question'.freeze

  def initialize(assistant, conversation)
    @assistant = assistant
    @conversation = conversation
  end

  def remaining
    return @assistant.lead_max_questions unless @conversation

    messages = @conversation.messages
    boundary = messages.where(message_type: :activity).reorder(id: :desc)
                       .detect { |message| message.content_attributes.dig('activity', 'status') == 'resolved' }&.id
    questions = messages.where(sender: @assistant, private: false)
                        .where('additional_attributes @> ?', { ATTRIBUTE_KEY => true }.to_json)
    questions = questions.where('id > ?', boundary) if boundary
    [@assistant.lead_max_questions - questions.count, 0].max
  end

  def enforce!(run_result)
    state = run_result.context.to_h.fetch(:state, {})
    return if state.fetch(:lead_intake, {}).values_at(:captured, :form_pending).any?

    output = run_result.output
    return unless qualification_question?(output) && remaining.zero?

    parts = Captain::Assistant::ResponseParts.from_response(output.except('follow_up')).to_a.map(&:dup)
    # A schema v2 question is its own field: dropping it leaves the answer as written.
    remove_last_question(parts) unless output.delete('follow_up')
    parts << { 'text' => I18n.t('captain.leads.question_limit_reply'), 'citation_indexes' => [] } if parts.empty?
    output['response_parts'] = parts
    output['lead_qualification_question'] = false
    output['suggested_replies'] = []
  end

  private

  def qualification_question?(output)
    output['lead_qualification_question'] == true || output.dig('follow_up', 'kind') == 'qualification'
  end

  def remove_last_question(parts)
    parts.reverse_each do |part|
      text = part.fetch('text')
      question = Captain::Reply::Policies::FollowUp.question_in(text)
      next unless question

      part['text'] = text.sub(question, '').strip
      break
    end
    parts.reject! { |part| part['text'].blank? }
  end
end

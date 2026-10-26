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
    return unless run_result.output['lead_qualification_question'] == true && remaining.zero?

    output = run_result.output
    parts = Captain::Assistant::ResponseParts.from_response(output).to_a.map(&:dup)
    remove_last_question(parts)
    parts << { 'text' => I18n.t('captain.leads.followup_offer'), 'citation_indexes' => [] }
    output['response_parts'] = parts
    output['lead_qualification_question'] = false
    output['suggested_replies'] = []
  end

  private

  def remove_last_question(parts)
    text = parts.last.fetch('text')
    question = text[Captain::Conversation::ReplyComposer::TRAILING_QUESTION, 1]
    if question
      parts.last['text'] = text.delete_suffix(question).strip
    else
      parts.pop
    end
    parts.reject! { |part| part['text'].blank? }
  end
end

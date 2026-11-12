# When a person answered a knowledge gap in one of its conversations, the fast model turns that reply into a general
# draft answer the store owner can approve. Never counted as AI usage.
class Captain::KnowledgeGaps::DraftAnswer
  OCCURRENCES = 5
  REPLIES = 3
  REPLY_CHARS = 1500
  TIMEOUT_SECONDS = 20

  PROMPT = <<~PROMPT.freeze
    A store's AI assistant could not answer a customer question, and a person from the store replied instead.
    You get the general question and the person's replies. Reply with one JSON object: {"draft_answer": "..."}.

    If the replies answer the question in a way that holds for every customer who asks it, write a short answer for
    the store's FAQ: in the question's language, in the store's voice, without names, order numbers, emails, phone
    numbers, dates of this conversation or anything only about this customer.
    If they don't (the person asked for details, said they would check, or only handled this customer's case),
    reply {"draft_answer": null}.
  PROMPT

  def initialize(gap)
    @gap = gap
  end

  def perform
    return if !@gap.knowledge? || @gap.draft_answer.present?

    replies = human_replies
    return if replies.blank?

    response = chat.ask({ question: @gap.question, store_replies: replies }.to_json)
    output = response.content.is_a?(Hash) ? response.content : JSON.parse(response.content.to_s)
    draft = output['draft_answer'].to_s.strip
    @gap.update!(draft_answer: draft) if draft.present?
  end

  private

  # The first occurrence (newest first) whose conversation has public replies by a person after the question.
  def human_replies
    @gap.occurrences.includes(:conversation).order(created_at: :desc).limit(OCCURRENCES).each do |occurrence|
      messages = occurrence.conversation.messages.outgoing.where(private: false, sender_type: 'User')
      messages = if occurrence.message_id
                   messages.where('messages.id > ?', occurrence.message_id)
                 else
                   messages.where(created_at: occurrence.created_at..)
                 end
      texts = messages.reorder(:id).limit(REPLIES).pluck(:content).compact_blank
      return texts.join("\n").truncate(REPLY_CHARS) if texts.any?
    end
    nil
  end

  def chat
    Captain::Assistant::TieredLlmClient.chat(account_id: @gap.account_id, model: ENV.fetch('CAPTAIN_INTENT_ROUTER_MODEL', 'intent-router'),
                                             timeout: TIMEOUT_SECONDS)
                                       .with_params(max_tokens: 500, response_format: { type: 'json_object' })
                                       .with_instructions(PROMPT)
  end
end

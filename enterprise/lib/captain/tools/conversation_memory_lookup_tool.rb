class Captain::Tools::ConversationMemoryLookupTool < Captain::Tools::BasePublicTool
  description 'Read original public messages from this conversation when historical memory lacks an exact detail. ' \
              'Use an evidence message ID or a short literal product/phrase search. Historical statements are not current live data.'
  param :message_id, type: 'integer', required: false, desc: 'Original message ID referenced by a memory fact.'
  param :query, type: 'string', required: false, desc: 'Short literal phrase to find in older public messages.'

  def perform(tool_context, message_id: nil, query: nil)
    conversation = find_conversation(tool_context.state)
    return 'Conversation not found.' unless conversation
    return 'Provide a message ID or search phrase.' unless message_id || query.present?

    messages = conversation.messages.where(private: false, message_type: [:incoming, :outgoing])
    messages = matching_messages(messages, message_id, query)
    messages = messages.reorder(id: :desc).limit(3).to_a.reverse
    messages.reject!(&:deleted)
    return 'No matching public messages found.' if messages.empty?

    messages.map do |message|
      "Historical message #{message.id} (#{message.message_type}, #{message.created_at.iso8601}): #{message.content.to_s.truncate(3000)}"
    end.join("\n")
  end

  private

  def matching_messages(messages, message_id, query)
    if message_id
      messages.where(id: message_id)
    else
      messages.where('content ILIKE ?', "%#{ActiveRecord::Base.sanitize_sql_like(query)}%")
    end
  end

  def safe_to_run_after_new_customer_message? = true
end

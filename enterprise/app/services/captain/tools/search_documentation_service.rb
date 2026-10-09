class Captain::Tools::SearchDocumentationService < Captain::Tools::BaseTool
  def self.name
    'search_documentation'
  end
  description 'Search and retrieve documentation from knowledge base'

  param :query, desc: 'Search Query', required: true

  def execute(query:)
    Rails.logger.info { "#{self.class.name}: #{query}" }
    return search_knowledge(query) if assistant.account.dify_knowledge_enabled?

    responses = search_responses(query)
    return 'No FAQs found for the given query' if responses.empty?

    responses.map { |response| format_response(response) }.join
  end

  private

  def search_responses(query)
    translated_query = Captain::Llm::TranslateQueryService
                       .new(account: assistant.account)
                       .translate(query, target_language: assistant.account.locale_english_name)

    responses = assistant.responses.approved.enabled_for_search
    responses = responses.visible_to_customers if @user.blank?
    responses.search(translated_query)
  end

  def search_knowledge(query)
    # Copilot passes the agent; the V1 customer assistant passes no user.
    passages = Captain::Knowledge::Search.new(assistant, actor: @user, for_agents: @user.present?).search(query)
    return 'No knowledge found for the given query' if passages.empty?

    passages.map(&:to_tool_result).join
  end

  def format_response(response)
    formatted_response = "
        Question: #{response.question}
        Answer: #{response.answer}
        "
    if response.documentable.present? && response.documentable.try(:external_link)
      formatted_response += "
          Source: #{response.documentable.external_link}
          "
    end

    formatted_response
  end
end

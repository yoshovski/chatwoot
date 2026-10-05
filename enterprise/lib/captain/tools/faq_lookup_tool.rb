class Captain::Tools::FaqLookupTool < Captain::Tools::BasePublicTool
  description 'Search FAQs, documents and connected product knowledge to find relevant answers'
  param :query, type: 'string', desc: 'The question or topic to search for in the knowledge base'

  def perform(tool_context, query:)
    log_tool_usage('searching', { query: query })
    return search_knowledge(tool_context, query) if @assistant.account.dify_knowledge_enabled?

    # Use existing vector search on approved responses
    responses = @assistant.responses.approved.search(query).includes(:documentable).to_a
    record_retrieved_sources(tool_context, responses)

    if responses.empty?
      log_tool_usage('no_results', { query: query })
      "No relevant FAQs found for: #{query}"
    else
      log_tool_usage('found_results', { query: query, count: responses.size })
      format_responses(tool_context, responses)
    end
  end

  private

  def search_knowledge(tool_context, query)
    passages = Captain::Knowledge::Search.new(@assistant).search(query)
    return "No relevant knowledge found for: #{query}" if passages.empty?

    record_knowledge_sources(tool_context, passages)
    log_tool_usage('found_results', { query: query, count: passages.size })
    passages.map { |passage| format_passage(tool_context, passage) }.join
  end

  def record_knowledge_sources(tool_context, passages)
    record_retrieved_sources(tool_context, passages.select { |passage| passage.kind == 'faq' }.map(&:record))
    metadata = tool_context.state[:cw_metadata] ||= {}
    document_ids = passages.select { |passage| passage.kind == 'document' }.map { |passage| passage.record.id }
    metadata[:document_ids] = Array(metadata[:document_ids]) | document_ids
  end

  def format_passage(tool_context, passage)
    result = "\nKnowledge result:\nTitle: #{passage.title}\n#{passage.content}\n"
    if @assistant.citations_enabled? && passage.customer_visible_source_url.present?
      details = tool_context.state[Captain::Assistant::CITATION_DETAILS_STATE_KEY] ||= {}
      details[passage.source_reference] = passage.citation_detail
      result += "Citation index: #{citation_index_for_source(tool_context, passage.source_reference)}\n"
    end
    result
  end

  def safe_to_run_after_new_customer_message?
    true
  end

  def record_retrieved_sources(tool_context, responses)
    return if responses.empty?

    metadata = tool_context.state[:cw_metadata] ||= {}
    metadata[:faq_ids] = Array(metadata[:faq_ids]) | responses.map(&:id)

    responses_by_type = responses.group_by(&:documentable_type)
    document_ids = Array(responses_by_type['Captain::Document']).map(&:documentable_id)
    metadata[:document_ids] = Array(metadata[:document_ids]) | document_ids

    used_faq_ids = Array(responses_by_type['User']).map(&:id)
    metadata[:used_faq_ids] = Array(metadata[:used_faq_ids]) | used_faq_ids
  end

  def format_responses(tool_context, responses)
    responses.map { |response| format_response(tool_context, response) }.join
  end

  def format_response(tool_context, response)
    formatted_response = "
        Knowledge result:
        "
    if @assistant.citations_enabled? && response.customer_visible_source_url.present?
      formatted_response += "
          Citation index: #{citation_index(tool_context, response)}
          "
    end
    formatted_response += "
        Question: #{response.question}
        Answer: #{response.answer}
        "

    formatted_response
  end

  def citation_index(tool_context, response)
    citation_index_for_source(tool_context, "faq:#{response.id}")
  end

  def citation_index_for_source(tool_context, reference)
    citation_document_ids = tool_context.state[Captain::Assistant::CITATION_SOURCES_STATE_KEY] ||= {}
    existing_index = citation_document_ids.find { |_index, source| source == reference }&.first
    return existing_index if existing_index.present?

    next_citation_index = citation_document_ids.size + 1
    citation_document_ids[next_citation_index] = reference
    next_citation_index
  end
end

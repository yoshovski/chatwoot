class Captain::Tools::FaqLookupTool < Captain::Tools::BasePublicTool
  include Captain::Tools::SourceIndexing

  # Results scoring this far below the search's best hit are noise; agents don't see them unless the reply used them.
  LOW_RELEVANCE_MARGIN = 0.2

  description 'Search FAQs, documents and connected product knowledge to find relevant answers'
  param :query, type: 'string', desc: 'A few key words from the latest customer question, such as "opening hours" or "Agras T100 battery". ' \
                                      'For a new topic, leave out earlier products and requests. Leave out the store name and filler words.'

  def perform(tool_context, query:)
    query = without_business_name(query)
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

  # Models tend to prefix searches with the business name, which only adds noise to retrieval.
  def without_business_name(query)
    name = @assistant.config['product_name'].to_s.strip
    return query if name.blank?

    query.gsub(/\b#{Regexp.escape(name)}\b('s)?/i, ' ').squish.presence || query
  end

  def search_knowledge(tool_context, query)
    passages = Captain::Knowledge::Search.new(@assistant).search(query)
    return "No relevant knowledge found for: #{query}" if passages.empty?

    record_knowledge_sources(tool_context, passages)
    log_tool_usage('found_results', { query: query, count: passages.size })
    record_source_details(tool_context, passages, query)
    passages.map { |passage| format_passage(tool_context, passage) }.join
  end

  # A document can return several chunks; its best chunk decides the excerpt and relevance.
  def record_source_details(tool_context, passages, query)
    best_score = passages.map { |passage| passage.score.to_f }.max
    passages.group_by(&:source_reference).each_value do |chunks|
      passage = chunks.max_by { |chunk| chunk.score.to_f }
      low_relevance = passage.score.to_f < best_score - LOW_RELEVANCE_MARGIN
      detail = passage.citation_detail.merge(passage_source_detail(passage, query), low_relevance: low_relevance)
      source_index_for(tool_context, passage.source_reference, detail)
    end
  end

  def record_knowledge_sources(tool_context, passages)
    record_retrieved_sources(tool_context, passages.select { |passage| passage.kind == 'faq' }.map(&:record))
    record_document_ids(tool_context, passages)
    record_catalog_handles(tool_context, passages)
  end

  def record_document_ids(tool_context, passages)
    metadata = tool_context.state[:cw_metadata] ||= {}
    document_ids = passages.select { |passage| passage.kind == 'document' }.map { |passage| passage.record.id }
    metadata[:document_ids] = Array(metadata[:document_ids]) | document_ids
  end

  def record_catalog_handles(tool_context, passages)
    catalog_handles = passages.select { |p| %w[catalog product].include?(p.kind) }.filter_map(&:handle)
    return if catalog_handles.blank?

    tool_context.state[:product_handles] = (Array(tool_context.state[:product_handles]) | catalog_handles)
    tool_context.state[Captain::Assistant::PRODUCT_HANDLES_STATE_KEY] = (
      Array(tool_context.state[Captain::Assistant::PRODUCT_HANDLES_STATE_KEY]) | catalog_handles
    )
  end

  def format_passage(tool_context, passage)
    index = source_index_for(tool_context, passage.source_reference, {})
    "\nKnowledge result:\nSource index: #{index}\nTitle: #{passage.title}\n#{passage.content}\n"
  end

  def passage_source_detail(passage, query)
    record = passage.record
    return faq_source_detail(record) if record.is_a?(Captain::AssistantResponse)

    product = %w[catalog product].include?(passage.kind)
    {
      kind: product ? 'product' : passage.kind,
      title: (passage.content[/^#\s+(.+)$/, 1] if product) || passage.title,
      excerpt: product ? product_excerpt(passage.content) : matched_excerpt(passage.content, query),
      document_id: record.is_a?(Captain::Document) ? record.id : nil
    }
  end

  def product_excerpt(content)
    source_excerpt(content[/^##\s*Product description\s*$(.+?)(?:^##\s|\z)/m, 1] || content.sub(/^#\s+.+$/, ''))
  end

  # FAQs generated from a document name it, so agents see them under that document instead of as separate sources.
  def faq_source_detail(response)
    detail = { kind: 'faq', title: response.question, excerpt: source_excerpt(response.answer), faq_id: response.id }
    document = response.documentable
    return detail unless document.is_a?(Captain::Document)

    detail.merge(document_id: document.id, document_title: document.name.presence || document.external_link)
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
    detail = faq_source_detail(response).merge(url: response.customer_visible_source_url)
    index = source_index_for(tool_context, "faq:#{response.id}", detail)

    "
        Knowledge result:
        Source index: #{index}
        Question: #{response.question}
        Answer: #{response.answer}
        "
  end
end

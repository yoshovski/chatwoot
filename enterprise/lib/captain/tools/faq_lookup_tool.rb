class Captain::Tools::FaqLookupTool < Captain::Tools::BasePublicTool
  include Captain::Tools::SourceIndexing

  # Results scoring this far below the search's best hit are noise; agents don't see them unless the reply used them.
  LOW_RELEVANCE_MARGIN = 0.2
  DIRECT_PASSAGES = 3
  DIRECT_CONTENT_CHARS = 8000
  MIN_PASSAGE_CHARS = 512
  NO_DIRECT_RESULTS = 'No relevant knowledge found.'.freeze

  description 'Search FAQs, documents and connected knowledge for specifications, box contents, compatibility, model differences, setup, ' \
              'warranty, shipping rules, payments and store policies. Search the customer\'s latest question in a few key words.'
  param :query, type: 'string', desc: 'A few key words from the latest customer question, such as "opening hours" or "model X200 battery". ' \
                                      'For a new topic, leave out earlier products and requests. Leave out the store name and filler words.'

  def perform(tool_context, query:)
    query = without_business_name(query)
    log_tool_usage('searching', { query: query })
    return search_knowledge(tool_context, query) if @assistant.account.dify_knowledge_enabled?

    # Use existing vector search on approved responses
    responses = @assistant.responses.approved.enabled_for_search.visible_to_customers.search(query).includes(:documentable).to_a
    record_retrieved_sources(tool_context, responses)

    if responses.empty?
      log_tool_usage('no_results', { query: query })
      "No relevant FAQs found for: #{query}"
    else
      log_tool_usage('found_results', { query: query, count: responses.size })
      format_responses(tool_context, responses)
    end
  end

  # Direct RAG retrieves all queries before touching shared citation state.
  def perform_queries(tool_context, queries:)
    normalized_queries = queries.map { |query| without_business_name(query) }
    results = retrieve_queries(normalized_queries)
    return NO_DIRECT_RESULTS if results.empty?

    if @assistant.account.dify_knowledge_enabled?
      format_direct_passages(tool_context, results, normalized_queries.join(' '))
    else
      results = results.uniq(&:id).first(DIRECT_PASSAGES)
      results = direct_budget(results) { |response| response.answer.to_s }
      record_retrieved_sources(tool_context, results)
      format_responses(tool_context, results)
    end
  end

  private

  def retrieve_queries(queries)
    # Provision once before parallel retrieval; provisioning can update assistant configuration.
    @assistant.ensure_dify_datasets! if @assistant.account.dify_knowledge_enabled?
    trace_context = OpenTelemetry::Context.current
    futures = queries.map do |query|
      Concurrent::Promises.future do
        OpenTelemetry::Context.with_current(trace_context) do
          ActiveRecord::Base.connection_pool.with_connection { retrieve_query(query) }
        end
      end
    end
    Concurrent::Promises.zip(*futures).wait!
    groups = futures.map(&:value!)
    # Give each query its best passage before filling the remaining context slots.
    groups.filter_map(&:first) + groups.flat_map { |group| group.drop(1) }
  end

  def retrieve_query(query)
    return Captain::Knowledge::Search.new(@assistant).search_prepared(query) if @assistant.account.dify_knowledge_enabled?

    @assistant.responses.approved.enabled_for_search.visible_to_customers.search(query).includes(:documentable).to_a
  end

  def format_direct_passages(tool_context, passages, query)
    passages = passages.uniq { |passage| [passage.source_reference, passage.content] }.first(DIRECT_PASSAGES)
    passages = budget_passages(passages)
    Rails.logger.info "[Captain][KnowledgeContext] assistant_id=#{@assistant.id} passages=#{passages.size} " \
                      "content_chars=#{passages.sum { |passage| passage.content.length }}"
    record_knowledge_sources(tool_context, passages)
    record_source_details(tool_context, passages, query)
    passages.map { |passage| format_passage(tool_context, passage) }.join
  end

  def budget_passages(passages)
    # Small FAQ hits should not take an equal share from a detailed product or policy.
    # Reserve evidence for every query topic, then give the best passages the unused space.
    remaining = DIRECT_CONTENT_CHARS
    passages.map.with_index do |passage, index|
      reserved = passages.drop(index + 1).sum { |other| [other.content.length, MIN_PASSAGE_CHARS].min }
      copy = passage.dup
      copy.content = copy.content.truncate(remaining - reserved)
      remaining -= copy.content.length
      copy
    end
  end

  def direct_budget(results)
    remaining = DIRECT_CONTENT_CHARS
    results.filter_map do |result|
      content = yield(result)
      next if content.length > remaining

      remaining -= content.length
      result
    end
  end

  # Models tend to prefix searches with the business name, which only adds noise to retrieval.
  def without_business_name(query)
    name = @assistant.config['product_name'].to_s.strip
    return query if name.blank?

    query.gsub(/\b#{Regexp.escape(name)}\b('s)?/i, ' ').squish.presence || query
  end

  def search_knowledge(tool_context, query)
    passages = Captain::Knowledge::Search.new(@assistant).search(query)
    return "No relevant knowledge found for: #{query}" if passages.empty?

    log_tool_usage('found_results', { query: query, count: [passages.size, DIRECT_PASSAGES].min })
    format_direct_passages(tool_context, passages, query)
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
    catalog_handles = passages.select { |p| %w[catalog product].include?(p.kind) }.filter_map do |p|
      p.handle.presence || p.content.to_s.match(/^\s*(?:-\s*)?Product handle:\s*([a-z0-9][a-z0-9_-]*)\s*$/i)&.captures&.first
    end
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

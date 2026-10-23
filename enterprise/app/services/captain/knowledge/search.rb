class Captain::Knowledge::Search
  prepend Captain::Knowledge::SearchTracing
  class Error < StandardError; end
  DATASET_TOP_K = 20
  NAMED_DOCUMENT_LIMIT = 2
  PASSAGE_CHARS = 8000
  TOTAL_CHARS = 24_000
  QUERY_FILLER = %w[a an the what are is your our you do does can could please tell me about].freeze
  DOCUMENT_TASK_TERMS = %w[how to set up setup configure configuration integrate integration guide documentation instruction step].freeze

  Passage = Struct.new(:kind, :title, :content, :score, :record, :document_id, :dataset_id, :source_url, :handle, keyword_init: true) do
    def source_document
      record.is_a?(Captain::AssistantResponse) ? record.documentable : record
    end

    def customer_visible_source_url
      source_url
    end

    def source_reference
      case kind
      when 'faq' then "faq:#{record.id}"
      when 'document' then "doc:#{record.id}"
      when 'extra' then "extra:#{document_id}"
      when 'product', 'catalog' then "product:#{handle.presence || document_id}"
      end
    end

    def citation_detail
      { dataset_id: dataset_id, url: source_url }
    end

    def to_tool_result
      result = "\nKnowledge result:\nTitle: #{title}\n#{content}\n"
      url = customer_visible_source_url
      result += "Source: #{url}\n" if url.present?
      result
    end
  end

  # Searches answer customers unless for_agents: agents-only documents and FAQs are left out of customer results.
  def initialize(assistant, actor: nil, for_agents: false)
    @assistant = assistant
    @account = assistant.account
    @actor = actor || assistant
    @for_agents = for_agents
  end

  def search(query, kinds: nil)
    @assistant.ensure_dify_datasets!
    search_prepared(query, kinds: kinds)
  end

  # Used after direct RAG has provisioned datasets before concurrent searches.
  def search_prepared(query, kinds: nil)
    datasets = configured_datasets
    datasets.select! { |dataset| kinds.include?(dataset[:kind]) || (dataset[:kind] == 'catalog' && kinds.include?('product')) } if kinds
    response = AiAgents::KnowledgeClient.new(account: @account, actor: @actor).request(
      method: :post, path: '/v1/knowledge/search', action: 'knowledge:read',
      payload: { account_id: @account.id, query: query, datasets: datasets }
    )
    raise Error, "Captain knowledge search failed (HTTP #{response.code})" unless response.code == 200

    passages = response.parsed_response.fetch('passages').filter_map { |passage| canonical_passage(passage, datasets) }
    self.class.within_budget(focus_named_documents(passages, query, datasets))
  end

  def self.within_budget(passages)
    total = 0
    passages.take_while { |passage| (total += passage.content.length) <= TOTAL_CHARS }
  end

  private

  # Named guides need their overall procedure as well as the matching chunk.
  # Keep all datasets searched, including evidence for other parts of the question.
  def focus_named_documents(passages, query, datasets)
    terms = title_terms(query) - QUERY_FILLER
    named, other = passages.partition { |passage| named_document?(passage, terms) }
    named += find_named_documents(terms, passages, datasets)
    return passages if named.empty?

    named = named.sort_by { |passage| title_rank(passage.title, terms) }.uniq(&:source_reference).map { |passage| expand_named_document(passage) }
    other.reject! { |passage| unrelated_catalog?(passage, terms) }
    named + other
  end

  def named_document?(passage, terms)
    passage.record.is_a?(Captain::Document) && title_matches?(passage.title, terms)
  end

  def title_matches?(name, terms)
    title = title_terms(name)
    return true if (terms.size > 1 || terms.first == title.first) && (terms - title).empty?

    (terms & title).size >= 2 && (terms - title - DOCUMENT_TASK_TERMS).empty?
  end

  def title_rank(name, terms)
    title = title_terms(name)
    [(title - terms).size, -(title & terms).size]
  end

  # Semantic retrieval can miss even a guide named verbatim. Supplement it only
  # with indexed, enabled documents belonging to this assistant and audience.
  def find_named_documents(terms, passages, datasets)
    dataset = datasets.find { |item| item[:kind] == 'document' }
    topic = terms - DOCUMENT_TASK_TERMS
    return [] unless dataset && terms.size >= 2 && topic.any?

    score = passages.map(&:score).max.to_f
    named_document_scope(terms).order(:id).limit(NAMED_DOCUMENT_LIMIT).map do |record|
      build_passage({ 'content' => '', 'score' => score, 'dataset_id' => dataset[:dataset_id] },
                    'document', record.metadata.fetch('dify_document_id'), record)
    end
  end

  def named_document_scope(terms)
    scope = Captain::Document.for_assistant(@assistant.id).for_account(@account.id).enabled.available
                             .where("metadata->>'dify_document_id' IS NOT NULL")
    scope = scope.where(agents_only: false) unless @for_agents
    (terms - DOCUMENT_TASK_TERMS).each { |term| scope = scope.where('name ILIKE ?', "%#{Captain::Document.sanitize_sql_like(term)}%") }
    matches = scope.pluck(:id, :name).select { |_, name| title_matches?(name, terms) }
    ids = matches.sort_by { |_, name| title_rank(name, terms) }.first(NAMED_DOCUMENT_LIMIT).map(&:first)
    scope.where(id: ids)
  end

  def unrelated_catalog?(passage, terms)
    %w[product catalog].include?(passage.kind) && !terms.intersect?(title_terms(passage.title))
  end

  def expand_named_document(passage)
    text = passage.record.content.to_s
    return passage if text.blank?

    passage.dup.tap do |copy|
      copy.content = if text.length <= PASSAGE_CHARS
                       text
                     else
                       Captain::Knowledge::DocumentExcerpt.new(passage, limit: PASSAGE_CHARS).perform
                     end
    end
  end

  def title_terms(text)
    text.downcase.scan(/[[:alnum:]]+/).reject { |word| QUERY_FILLER.include?(word) }.map { |word| word.sub(/ies\z/, 'y').sub(/(?<!s)s\z/, '') }.uniq
  end

  def configured_datasets
    datasets = [
      { dataset_id: @assistant.config.fetch('dify_faq_dataset_id'), kind: 'faq', limit: DATASET_TOP_K },
      { dataset_id: @assistant.config.fetch('dify_docs_dataset_id'), kind: 'document', limit: DATASET_TOP_K },
      *@assistant.config.fetch('dify_extra_dataset_ids', []).map { |id| { dataset_id: id, kind: 'extra', limit: DATASET_TOP_K } }
    ]
    catalog = shopify_catalog_dataset
    datasets << catalog if catalog
    datasets
  end

  def shopify_catalog_dataset
    return unless Shopify::FeatureGate.workspace_enabled?(@account)

    hook = @account.hooks.find_by(app_id: 'shopify')
    return unless hook&.shopify_connected? && hook.shopify_catalog_sync_enabled? && hook.shopify_catalog_dataset_id.present?

    { dataset_id: hook.shopify_catalog_dataset_id, kind: 'catalog', limit: DATASET_TOP_K }
  end

  def canonical_passage(passage, datasets)
    kind = passage.fetch('kind')
    return unless passage_matched?(datasets, passage.fetch('dataset_id'), kind)

    document_id = passage.fetch('document_id')
    record = canonical_record(kind, document_id)
    return if %w[faq document].include?(kind) && record.nil?
    return if record && !@for_agents && !record.visible_to_customers?

    build_passage(passage, kind, document_id, record)
  end

  def passage_matched?(datasets, dataset_id, kind)
    datasets.any? do |dataset|
      dataset[:dataset_id] == dataset_id &&
        (dataset[:kind] == kind || (dataset[:kind] == 'catalog' && %w[catalog product].include?(kind)))
    end
  end

  def build_passage(passage, kind, document_id, record)
    title, content = canonical_text(record, passage)
    handle = passage['handle'].presence || passage.dig('metadata', 'handle') || passage.dig('metadata', 'product_handle')
    # Catalog documents are titled by their Shopify handle, so product search and knowledge hits name the same source.
    handle ||= passage.fetch('title') if %w[catalog product].include?(kind)
    result = Passage.new(kind: kind, title: title.truncate(90), content: content.truncate(PASSAGE_CHARS),
                         score: passage.fetch('score'), record: record, document_id: document_id, dataset_id: passage.fetch('dataset_id'),
                         handle: handle)
    result.source_url = Captain::Knowledge::CitationSources.new(@assistant).url(
      result.source_reference, { dataset_id: result.dataset_id, url: passage['url'] }
    )
    result
  end

  def canonical_text(record, passage)
    return [record.question, "Question: #{record.question}\nAnswer: #{record.answer}"] if record.is_a?(Captain::AssistantResponse)
    # Dify only knows documents by their sync key ("Captain Document 65."), so name them as Chatwoot does.
    return [record.name.presence || record.external_link, passage.fetch('content')] if record.is_a?(Captain::Document)

    [passage.fetch('title'), passage.fetch('content')]
  end

  def canonical_record(kind, document_id)
    case kind
    when 'faq'
      response = @assistant.responses.approved.enabled_for_search.by_account(@account.id).find_by(dify_document_id: document_id)
      response if response&.grounded_source_current?
    when 'document'
      @assistant.documents.for_account(@account.id).enabled.available.find_by("metadata->>'dify_document_id' = ?", document_id)
    end
  end
end

class Captain::Knowledge::Search
  class Error < StandardError; end
  DATASET_TOP_K = 4
  PASSAGE_CHARS = 8000
  TOTAL_CHARS = 24_000

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
    datasets = configured_datasets
    datasets.select! { |dataset| kinds.include?(dataset[:kind]) || (dataset[:kind] == 'catalog' && kinds.include?('product')) } if kinds
    response = AiAgents::KnowledgeClient.new(account: @account, actor: @actor).request(
      method: :post, path: '/v1/knowledge/search', action: 'knowledge:read',
      payload: { account_id: @account.id, query: query, datasets: datasets }
    )
    raise Error, "Captain knowledge search failed (HTTP #{response.code})" unless response.code == 200

    passages = response.parsed_response.fetch('passages').filter_map { |passage| canonical_passage(passage, datasets) }
    self.class.within_budget(passages)
  end

  def self.within_budget(passages)
    total = 0
    passages.take_while { |passage| (total += passage.content.length) <= TOTAL_CHARS }
  end

  private

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
    when 'faq' then @assistant.responses.approved.enabled_for_search.by_account(@account.id).find_by(dify_document_id: document_id)
    when 'document'
      @assistant.documents.for_account(@account.id).enabled.available.find_by("metadata->>'dify_document_id' = ?", document_id)
    end
  end
end

class Captain::Knowledge::Search
  class Error < StandardError; end
  PASSAGE_CHARS = 8000
  TOTAL_CHARS = 24_000

  Passage = Struct.new(:kind, :title, :content, :score, :record, :document_id, keyword_init: true) do
    def source_document
      record.is_a?(Captain::AssistantResponse) ? record.documentable : record
    end

    def customer_visible_source_url
      source_document.customer_visible_source_url if source_document.is_a?(Captain::Document)
    end

    def to_tool_result
      result = "\nKnowledge result:\nTitle: #{title}\n#{content}\n"
      url = customer_visible_source_url
      result += "Source: #{url}\n" if url.present?
      result
    end
  end

  def initialize(assistant, actor: nil)
    @assistant = assistant
    @account = assistant.account
    @actor = actor || assistant
  end

  def search(query, kinds: nil)
    @assistant.ensure_dify_datasets!
    datasets = configured_datasets
    datasets.select! { |dataset| kinds.include?(dataset[:kind]) } if kinds
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
    [
      { dataset_id: @assistant.config.fetch('dify_faq_dataset_id'), kind: 'faq', limit: 6 },
      { dataset_id: @assistant.config.fetch('dify_docs_dataset_id'), kind: 'document', limit: 6 },
      *@assistant.config.fetch('dify_extra_dataset_ids', []).map { |id| { dataset_id: id, kind: 'extra', limit: 6 } }
    ]
  end

  def canonical_passage(passage, datasets)
    kind = passage.fetch('kind')
    return unless datasets.any? { |dataset| dataset[:dataset_id] == passage.fetch('dataset_id') && dataset[:kind] == kind }

    document_id = passage.fetch('document_id')
    record = canonical_record(kind, document_id)
    return if %w[faq document].include?(kind) && record.nil?

    title, content = canonical_text(record, passage)
    Passage.new(kind: kind, title: title.truncate(90), content: content.truncate(PASSAGE_CHARS),
                score: passage.fetch('score'), record: record, document_id: document_id)
  end

  def canonical_text(record, passage)
    return [record.question, "Question: #{record.question}\nAnswer: #{record.answer}"] if record.is_a?(Captain::AssistantResponse)

    [passage.fetch('title'), passage.fetch('content')]
  end

  def canonical_record(kind, document_id)
    case kind
    when 'faq' then @assistant.responses.approved.by_account(@account.id).find_by(dify_document_id: document_id)
    when 'document'
      @assistant.documents.for_account(@account.id).available.find_by("metadata->>'dify_document_id' = ?", document_id)
    end
  end
end

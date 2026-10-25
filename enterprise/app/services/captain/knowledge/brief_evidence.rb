class Captain::Knowledge::BriefEvidence
  include Captain::Tools::SourceIndexing
  EXCLUDED_STATUSES = %w[rejected candidate review].freeze

  def initialize(assistant)
    @assistant = assistant
  end

  def perform(tool_context)
    brief = verified_brief!
    snapshot = brief.published
    offerings = brief.usable_offerings(snapshot).reject { |item| EXCLUDED_STATUSES.include?(item['status']) }
    documents = load_permitted_documents(brief, snapshot, offerings, tool_context)
    build_evidence_blocks(snapshot, brief.usable_topics(snapshot), offerings, documents, tool_context)
  end

  private

  def verified_brief!
    brief = @assistant.knowledge_brief
    return brief if @assistant.config['knowledge_brief_enabled'] == true && brief&.usable?(brief.published)

    raise ArgumentError, 'Knowledge brief is unavailable'
  end

  def load_permitted_documents(brief, snapshot, offerings, tool_context)
    all_ids = (Array(snapshot['document_ids']) + offerings.flat_map { |o| Array(o['document_ids']) }).uniq
    documents = brief.permitted_documents(all_ids).index_by(&:id)
    record_documents(tool_context, documents.keys)
    documents
  end

  def build_evidence_blocks(snapshot, topics, offerings, documents, tool_context)
    original_quotes = index_original_quotes(offerings)
    overview = snapshot.fetch('overview').merge('title' => 'Business overview')
    summary_blocks = ([overview] + topics).filter_map { |s| format_summary(s, documents, tool_context, original_quotes) }
    offering_blocks = offerings.filter_map { |offering| format_offering(offering, documents, tool_context) }
    (summary_blocks + offering_blocks).join
  end

  def record_documents(tool_context, ids)
    metadata = tool_context.state[:cw_metadata] ||= {}
    metadata[:document_ids] = Array(metadata[:document_ids]) | ids
  end

  def index_original_quotes(offerings)
    offerings.each_with_object({}) do |offering, acc|
      Array(offering['evidence']).each do |ev|
        doc_id = ev['document_id'].to_i
        acc[doc_id] ||= ev['quote'] if ev['quote'].present?
      end
    end
  end

  def format_summary(summary, documents, tool_context, original_quotes)
    text = summary['text'] || summary.fetch('summary')
    valid_ids = Array(summary.fetch('document_ids')).select { |id| documents.key?(id) }
    return if valid_ids.empty?

    indexes = valid_ids.map do |id|
      document = documents.fetch(id)
      excerpt_text = original_quotes[id].presence || text
      source_index_for(tool_context, "doc:#{id}", { kind: 'document', title: document.name, document_id: id, excerpt: source_excerpt(excerpt_text) })
    end
    urls = valid_ids.filter_map { |id| documents.fetch(id).customer_visible_source_url }
    "\nApproved summary:\nTitle: #{summary.fetch('title')}\nSource indexes: #{indexes.join(', ')}\nSource URLs: #{urls.join(', ')}\n#{text}\n"
  end

  def format_offering(offering, documents, tool_context)
    evidence_items = Array(offering['evidence']).select { |ev| documents.key?(ev['document_id'].to_i) }
    return if evidence_items.empty?

    indexes = register_offering_sources(offering, evidence_items, documents, tool_context)
    urls = offering_urls(evidence_items, documents)
    quotes = evidence_items.filter_map { |ev| ev['quote'].to_s.strip.presence }.uniq.join(' | ')
    "\nApproved offering:\nName: #{offering.fetch('name')} (#{offering.fetch('kind')})\nPurpose: #{offering.fetch('purpose')}\n" \
      "Source indexes: #{indexes.join(', ')}\nSource URLs: #{urls.join(', ')}\nSupporting passage: #{quotes}\n"
  end

  def offering_urls(evidence_items, documents)
    evidence_items.filter_map { |ev| documents[ev['document_id'].to_i]&.customer_visible_source_url }.uniq
  end

  def register_offering_sources(offering, evidence_items, documents, tool_context)
    evidence_items.map do |ev|
      doc_id = ev['document_id'].to_i
      document = documents.fetch(doc_id)
      quote = ev['quote'].to_s.presence || offering['purpose'].to_s
      source_index_for(tool_context, "doc:#{doc.id}", { kind: 'document', title: document.name, document_id: doc_id, excerpt: source_excerpt(quote) })
    end.uniq
  end
end

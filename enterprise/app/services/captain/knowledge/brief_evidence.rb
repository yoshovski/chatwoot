class Captain::Knowledge::BriefEvidence
  include Captain::Tools::SourceIndexing

  def initialize(assistant)
    @assistant = assistant
  end

  def perform(tool_context)
    brief = @assistant.knowledge_brief
    unless @assistant.config['knowledge_brief_enabled'] == true && brief&.usable?(brief.published)
      raise ArgumentError,
            'Knowledge brief is unavailable'
    end

    snapshot = brief.published
    documents = @assistant.documents.where(id: snapshot.fetch('document_ids')).index_by(&:id)
    record_documents(tool_context, documents.keys)
    ([snapshot.fetch('overview').merge('title' => 'Business overview')] + snapshot.fetch('topics')).map do |summary|
      format_summary(summary, documents, tool_context)
    end.join
  end

  private

  def record_documents(tool_context, ids)
    metadata = tool_context.state[:cw_metadata] ||= {}
    metadata[:document_ids] = Array(metadata[:document_ids]) | ids
  end

  def format_summary(summary, documents, tool_context)
    text = summary['text'] || summary.fetch('summary')
    indexes = summary.fetch('document_ids').map do |id|
      document = documents.fetch(id)
      source_index_for(tool_context, "doc:#{id}", { kind: 'document', title: document.name, document_id: id, excerpt: source_excerpt(text) })
    end
    urls = summary.fetch('document_ids').filter_map { |id| documents.fetch(id).customer_visible_source_url }
    "\nApproved summary:\nTitle: #{summary.fetch('title')}\nSource indexes: #{indexes.join(', ')}\nSource URLs: #{urls.join(', ')}\n#{text}\n"
  end
end

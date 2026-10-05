module Captain::Dify::DocumentResponseBuilderJob
  def perform(document, options = {})
    return if document.pdf_document?
    return if document.account.dify_knowledge_enabled? && (!document.available? || document.dify_indexing_status != 'completed')

    super
  end
end

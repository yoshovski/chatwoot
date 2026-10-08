module Captain::Dify::DocumentResponseBuilderJob
  def perform(document, options = {})
    return if document.pdf_document?

    opts = options.respond_to?(:with_indifferent_access) ? options.with_indifferent_access : options
    return if document.account.dify_knowledge_enabled? && !opts[:force_ai] && (!document.available? || document.dify_indexing_status != 'completed')

    super
  end
end

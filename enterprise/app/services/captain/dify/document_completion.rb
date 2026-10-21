# Applies a completed Dify indexing state to a document. Shared by polling and the timeout recheck.
class Captain::Dify::DocumentCompletion
  def initialize(document, state)
    @document = document
    @state = state
  end

  # Returns true when a website page became Ready, so its own page FAQs can be imported.
  def apply
    unless searchable?
      @document.mark_dify_sync_failed!('dify_document_unavailable')
      return false
    end

    @document.update!(status: :available, sync_status: :synced, dify_indexing_status: 'completed', sync_step: nil,
                      last_sync_error_code: nil, last_synced_at: Time.current, last_sync_attempted_at: Time.current)
    !@document.pdf_document?
  end

  private

  def searchable?
    @state.fetch('enabled') && !@state.fetch('archived') && @state.fetch('doc_form') == 'hierarchical_model'
  end
end

class Captain::Websites::ImportPageJob < ApplicationJob
  class TemporaryFetchError < StandardError; end

  queue_as :low
  discard_on ActiveRecord::RecordNotFound
  retry_on TemporaryFetchError, wait: :polynomially_longer, attempts: 4
  # Below this a page is a stub or an empty shell, even when an administrator selected it.
  MIN_WORDS = 25

  def perform(document_id)
    document = Captain::Document.find(document_id)
    source = document.assistant.website_sources.find(document.metadata.fetch('website_source_id'))
    return unless selected?(document)

    result = Captain::Websites::PageFetcher.new(source).fetch(document.external_link)
    document.reload
    return unless selected?(document)

    persist_result(document, result)
  rescue TemporaryFetchError, ActiveRecord::RecordNotFound
    raise
  rescue StandardError
    document&.update!(sync_status: :failed, sync_step: nil, last_sync_error_code: 'sync_error', last_sync_attempted_at: Time.current)
    raise
  end

  private

  def selected?(document)
    document.enabled? && document.assistant.website_sources.exists?(['selected_urls @> ?::jsonb', [document.external_link].to_json])
  end

  def persist_result(document, result)
    unless result.success
      skip(document, result.error_code)
      raise TemporaryFetchError, result.error_code if result.error_code.in?(%w[timeout fetch_failed])

      return
    end

    content = Captain::Documents::PageKnowledgeProcessor.new(document).perform(result.content)
    return unless selected?(document)

    fingerprint = Digest::SHA256.hexdigest(content.gsub(/\s+/, ' ').strip)
    reason = skip_reason(document, content, fingerprint)
    reason ? skip(document, reason) : store(document, result, content, fingerprint)
  end

  def store(document, result, content, fingerprint)
    document.metadata = document.metadata.merge('page_faqs' => result.faqs || [], 'page_text_fingerprint' => fingerprint)
    document.update!(name: result.title.presence || document.name, content: content, status: :available,
                     sync_status: :synced, last_synced_at: Time.current, last_sync_attempted_at: Time.current, last_sync_error_code: nil)
  end

  def skip(document, error_code)
    document.update!(status: :available, sync_status: :failed, last_sync_error_code: error_code, last_sync_attempted_at: Time.current)
  end

  # A stub page, or text another enabled page of this agent already holds (a mirror, print or locale copy).
  def skip_reason(document, content, fingerprint)
    return 'thin_content' if content.split.size < MIN_WORDS

    duplicate = document.assistant.documents.where(enabled: true).where.not(id: document.id)
                        .exists?(["metadata->>'page_text_fingerprint' = ?", fingerprint])
    'duplicate_content' if duplicate
  end
end

class Captain::Websites::ImportPageJob < ApplicationJob
  class TemporaryFetchError < StandardError; end

  queue_as :low
  discard_on ActiveRecord::RecordNotFound
  retry_on TemporaryFetchError, wait: :polynomially_longer, attempts: 4
  # Below this a page is a stub or an empty shell, even when an administrator selected it.
  MIN_WORDS = 25
  # A first import that finds nothing usable removes the document and excludes the page in the picker.
  DISCARDED = { 'not_found' => 'not_found', 'thin_content' => 'thin', 'duplicate_content' => 'duplicate',
                'access_denied' => 'login', 'robots_disallowed' => 'robots_disallowed' }.freeze

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

    content = processed_content(document, result)
    return skip(document, 'thin_content') if content.nil?
    return unless selected?(document)

    fingerprint = Digest::SHA256.hexdigest(content.gsub(/\s+/, ' ').strip)
    minhash = Captain::Knowledge::MinHash.of(content)
    reason = skip_reason(document, content, fingerprint, minhash)
    reason ? skip(document, reason) : store(document, result, content, fingerprint, minhash)
  end

  # nil when cleaning leaves no factual text.
  def processed_content(document, result)
    Captain::Documents::PageKnowledgeProcessor.new(document).perform(result.content)
  rescue Captain::Documents::PageKnowledgeProcessor::NoContent
    nil
  end

  def store(document, result, content, fingerprint, minhash)
    document.metadata = document.metadata.merge('page_faqs' => result.faqs || [], 'page_text_fingerprint' => fingerprint,
                                                'page_minhash' => minhash)
    document.update!(name: result.title.presence || document.name, content: content, status: :available,
                     sync_status: :synced, last_synced_at: Time.current, last_sync_attempted_at: Time.current, last_sync_error_code: nil)
  end

  def skip(document, error_code)
    return discard(document, DISCARDED[error_code]) if DISCARDED.key?(error_code) && document.last_synced_at.nil?

    document.update!(status: :available, sync_status: :failed, last_sync_error_code: error_code, last_sync_attempted_at: Time.current)
  end

  def discard(document, reason)
    source = document.assistant.website_sources.find(document.metadata.fetch('website_source_id'))
    url = document.external_link
    issue = reason == 'robots_disallowed' ? { 'blocked_reason' => reason } : { 'import_issue' => reason }
    source.with_lock do
      pages = source.pages.map { |page| page['url'] == url ? page.merge(issue) : page }
      source.update!(selected_urls: source.selected_urls - [url], pages: Captain::Websites::PageBuckets.new(source).perform(pages))
    end
    document.destroy!
  end

  # A stub page, or text another enabled page of this agent already holds, exactly or nearly
  # (a mirror, print or locale copy, or the same page with another footer or date).
  def skip_reason(document, content, fingerprint, minhash)
    return 'thin_content' if content.split.size < MIN_WORDS

    others = document.assistant.documents.where(enabled: true).where.not(id: document.id)
    duplicate = others.exists?(["metadata->>'page_text_fingerprint' = ?", fingerprint]) ||
                others.where("metadata ? 'page_minhash'").pluck(Arel.sql("metadata->>'page_minhash'"))
                      .any? { |other| Captain::Knowledge::MinHash.near?(other, minhash) }
    'duplicate_content' if duplicate
  end
end

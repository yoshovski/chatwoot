class Captain::Tools::SimplePageCrawlParserJob < ApplicationJob
  class PermanentCrawlError < StandardError; end
  # Rate limits (429), overloaded or unreachable sites: the page is retried and shown as syncing, not failed.
  class TemporaryCrawlError < StandardError; end

  # nil is a network error without an HTTP status.
  TEMPORARY_STATUS_CODES = [nil, 408, 425, 429, 500, 502, 503, 504].freeze
  MAX_ATTEMPTS = 6

  queue_as :low

  discard_on PermanentCrawlError
  retry_on TemporaryCrawlError, wait: :polynomially_longer, attempts: MAX_ATTEMPTS do |job, _error|
    job.mark_failed_after_retries
  end

  def mark_failed_after_retries
    arguments.first => { assistant_id:, page_link: }
    document = Captain::Document.find_by(assistant_id: assistant_id, external_link: normalize_link(page_link))
    mark_failed!(document, 'fetch_failed') if document
  end

  def perform(assistant_id:, page_link:)
    assistant = Captain::Assistant.find(assistant_id)
    account = assistant.account

    if limit_exceeded?(account)
      Rails.logger.info("Document limit exceeded for #{assistant_id}")
      return
    end

    crawler = Captain::Tools::SimplePageCrawlService.new(page_link)
    normalized_link = normalize_link(page_link)
    document = assistant.documents.find_or_initialize_by(external_link: normalized_link)

    handle_failed_fetch!(document, crawler.status_code, page_link) unless crawler.success?

    persist_document!(document, normalized_link, crawler)
  rescue PermanentCrawlError, TemporaryCrawlError
    raise
  rescue StandardError => e
    raise "Failed to parse data: #{page_link} #{e.message}"
  end

  private

  def handle_failed_fetch!(document, status_code, page_link)
    error_message = "Failed to fetch page: #{page_link} (HTTP #{status_code || 'none'})"
    if TEMPORARY_STATUS_CODES.include?(status_code)
      document.update!(sync_status: :syncing, last_sync_attempted_at: Time.current) if document.persisted?
      raise TemporaryCrawlError, error_message
    end

    error_code = http_error_code(status_code)
    mark_failed!(document, error_code) if document.persisted?
    raise PermanentCrawlError, error_message if permanent_failure?(error_code)

    raise error_message
  end

  def persist_document!(document, normalized_link, crawler)
    content = crawler.body_markdown_without_faqs.presence || crawler.page_title.presence || ''
    content = content[0...Captain::Documents::SinglePageFetcher::CONTENT_MAX_LENGTH]
    metadata = (document.metadata || {}).merge('page_faqs' => crawler.faqs)

    document.update!(
      external_link: normalized_link,
      name: (crawler.page_title || '')[0..254],
      content: content,
      metadata: metadata,
      status: :available,
      **synced_attributes
    )
  end

  def synced_attributes
    {
      sync_status: :synced,
      last_synced_at: Time.current,
      last_sync_attempted_at: Time.current,
      last_sync_error_code: nil
    }
  end

  def mark_failed!(document, error_code)
    document.update!(
      status: :available,
      sync_status: :failed,
      last_sync_error_code: error_code,
      last_sync_attempted_at: Time.current
    )
  end

  def http_error_code(status_code)
    case status_code
    when 404 then 'not_found'
    when 401, 403 then 'access_denied'
    when 408, 504 then 'timeout'
    else 'fetch_failed'
    end
  end

  def permanent_failure?(error_code)
    Captain::Documents::SyncService::PERMANENT_ERROR_CODES.include?(error_code)
  end

  def normalize_link(raw_link)
    raw_link.to_s.delete_suffix('/')
  end

  def limit_exceeded?(account)
    limits = account.usage_limits[:captain][:documents]
    limits[:current_available].negative? || limits[:current_available].zero?
  end
end

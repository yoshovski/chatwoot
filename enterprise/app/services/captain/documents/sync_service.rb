class Captain::Documents::SyncService
  class PermanentSyncError < StandardError
  end

  class TransientSyncError < StandardError
  end

  PERMANENT_ERROR_CODES = %w[not_found access_denied content_empty rendering_required robots_disallowed].freeze

  def initialize(document)
    @document = document
  end

  def perform
    @document.update!(sync_step: 'fetching')
    # A Firecrawl scrape costs a credit; without it, or for a markdown copy, the fetch is free, so only then ask the page first.
    validators = Captain::Documents::PageValidators.new(@document) if Captain::Tools::FirecrawlService.configured? && source_page&.dig('markdown_url').nil?
    if validators&.not_modified?
      mark_synced
      return :not_modified
    end

    result = prepare_page(fetch_page)
    @page_metadata = validators&.metadata

    @document.update!(sync_step: 'comparing')
    new_fingerprint = compute_fingerprint(result.content)
    previous_fingerprint = @document.content_fingerprint

    if new_fingerprint == previous_fingerprint
      mark_synced
      return :unchanged
    end

    @document.update!(sync_step: 'updating')
    update_content(result, new_fingerprint)

    # Without a prior fingerprint we cannot tell a first-ever sync apart from a real
    # change, so treat it as unchanged to keep downstream signals quiet on baseline.
    previous_fingerprint.present? ? :updated : :unchanged
  end

  private

  def prepare_page(result)
    handle_fetch_error(result.error_code) unless result.success
    result.content = Captain::Documents::PageKnowledgeProcessor.new(@document).perform(result.content)
    result
  end

  def fetch_page
    return Captain::Documents::SinglePageFetcher.new(@document.external_link).fetch unless source

    Captain::Websites::PageFetcher.new(source).fetch(@document.external_link)
  end

  def source
    return @source if defined?(@source)

    source_id = @document.metadata.to_h['website_source_id']
    @source = (@document.assistant.website_sources.find(source_id) if source_id)
  end

  def source_page = source&.pages&.find { |page| page['url'] == @document.external_link }

  def compute_fingerprint(content)
    Digest::SHA256.hexdigest(content.gsub(/\s+/, ' ').strip)
  end

  def mark_failed(error_code)
    @document.update!(
      sync_status: :failed,
      sync_step: nil,
      last_sync_error_code: error_code,
      last_sync_attempted_at: Time.current
    )
  end

  # Rails assigns Hash values last, so passing `metadata:` to update! would discard the store
  # accessors (content_fingerprint, sync_step) in the same call; assign it first instead.
  def mark_synced
    @document.metadata = merged_metadata
    @document.update!(
      sync_status: :synced,
      sync_step: nil,
      last_synced_at: Time.current,
      last_sync_attempted_at: Time.current,
      last_sync_error_code: nil
    )
  end

  def update_content(result, fingerprint)
    @document.metadata = merged_metadata('page_faqs' => (result.faqs || []))
    @document.update!(
      content: result.content,
      name: result.title.presence || @document.name,
      content_fingerprint: fingerprint,
      sync_status: :synced,
      sync_step: nil,
      last_synced_at: Time.current,
      last_sync_attempted_at: Time.current,
      last_sync_error_code: nil
    )
    mark_synced if @document.account.dify_knowledge_enabled? && !@document.previous_changes.key?('content')
  end

  def merged_metadata(extra = {})
    (@document.metadata || {}).merge(@page_metadata.to_h).merge(extra)
  end

  def handle_fetch_error(error_code)
    if PERMANENT_ERROR_CODES.include?(error_code)
      mark_failed(error_code)
      raise PermanentSyncError, error_code
    end

    raise TransientSyncError, error_code
  end
end

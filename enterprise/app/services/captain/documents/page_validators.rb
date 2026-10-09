# Cheap HTTP check that tells whether a page changed, so auto-sync can skip a paid Firecrawl scrape.
class Captain::Documents::PageValidators
  FULL_FETCH_INTERVAL = 7.days
  NOT_MODIFIED = 304
  OK = 200
  READ_TIMEOUT = 10

  def initialize(document)
    @document = document
  end

  def not_modified?
    return false unless conditional_request_due?

    @probe = probe(conditional_headers)
    return false if @probe.nil?

    @probe.status == NOT_MODIFIED || (@probe.status == OK && stored_etag.present? && same_etag?(@probe.headers['etag']))
  end

  # Validators to store after a full fetch; unknown validators are cleared so a stale one is never sent again.
  def metadata
    live = @probe if @probe&.status == OK
    live ||= probe({})
    {
      'http_etag' => live&.headers&.dig('etag'),
      'http_last_modified' => live&.headers&.dig('last-modified'),
      'last_full_fetch_at' => Time.current.iso8601
    }
  end

  private

  def stored_etag
    @document.metadata.to_h['http_etag']
  end

  def stored_last_modified
    @document.metadata.to_h['http_last_modified']
  end

  def conditional_request_due?
    return false if stored_etag.blank? && stored_last_modified.blank?

    last_full_fetch_at = Time.zone.parse(@document.metadata.to_h['last_full_fetch_at'].to_s)
    last_full_fetch_at.present? && last_full_fetch_at > FULL_FETCH_INTERVAL.ago
  end

  def conditional_headers
    { 'If-None-Match' => stored_etag, 'If-Modified-Since' => stored_last_modified }.compact_blank
  end

  def same_etag?(etag)
    etag.to_s.delete_prefix('W/') == stored_etag.to_s.delete_prefix('W/')
  end

  def probe(headers)
    SafeFetch.probe(@document.external_link, headers: headers, read_timeout: READ_TIMEOUT)
  rescue SafeFetch::Error
    nil
  end
end

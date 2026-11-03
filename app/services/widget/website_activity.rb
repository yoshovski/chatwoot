class Widget::WebsiteActivity
  HISTORY_LIMIT = 50
  TITLE_LIMIT = 200
  URL_LIMIT = 2048
  UTM_LIMIT = 100
  UTM_KEYS = %w[utm_source utm_medium utm_campaign].freeze
  HOST_PATTERN = /\A[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*\z/
  HOST_LIMIT = 253
  # A visit ends after this long without a page view; the next page view starts a new one.
  VISIT_GAP = 30.minutes

  def initialize(contact_inbox)
    @contact_inbox = contact_inbox
  end

  # visit: { arrival:, timezone: } from the widget. arrival is { referrer_host:, utm_source:, utm_medium:, utm_campaign: }
  # as the visitor landed; it is kept only for a visit that has no arrival source yet. timezone: the browser's IANA zone.
  def record!(url:, title:, browser:, browser_language:, visit: {})
    page_url = sanitize_url(url)
    return if page_url.blank?

    @contact_inbox.with_lock do
      activity = @contact_inbox.website_activity
      now = Time.current
      page = { 'url' => page_url, 'title' => title.to_s.truncate(TITLE_LIMIT), 'last_seen_at' => now.iso8601(6), 'visited_at' => now.iso8601(6) }
      @contact_inbox.update!(website_activity: activity.merge(
        'browser' => browser,
        'browser_language' => browser_language,
        'current_page' => page,
        'recent_pages' => updated_history(activity, page),
        **visit_attributes(activity, now, visit[:arrival]),
        **timezone_attributes(visit[:timezone])
      ))
    end
    ActiveRecord.after_all_transactions_commit do
      Rails.configuration.dispatcher.dispatch('website_activity.updated', Time.zone.now, contact_inbox: @contact_inbox)
    end
  end

  private

  # A new visit starts its own arrival; its source comes from the first page view of the visit that carries one
  # (the widget posts it after the visitor's first message, which already recorded the page).
  def visit_attributes(activity, now, arrival)
    first_seen_at = activity['first_seen_at'] || activity.dig('recent_pages', 0, 'visited_at') || now.iso8601(6)
    attributes = { 'first_seen_at' => first_seen_at, 'visit_count' => activity['visit_count'] || 1 }
    current = activity['arrival']
    if new_visit?(activity, now)
      attributes['visit_count'] = activity['visit_count'].to_i + 1
      current = { 'landed_at' => now.iso8601(6) }
    end
    current ||= { 'landed_at' => first_seen_at }
    source = sanitize_arrival(arrival)
    attributes['arrival'] = current.keys == ['landed_at'] ? current.merge(source) : current
    attributes
  end

  def new_visit?(activity, now)
    last_seen_at = activity.dig('current_page', 'last_seen_at')
    last_seen_at.nil? || Time.zone.parse(last_seen_at) < now - VISIT_GAP
  end

  def timezone_attributes(timezone)
    return {} if timezone.blank?

    TZInfo::Timezone.get(timezone)
    { 'timezone' => timezone }
  rescue TZInfo::InvalidTimezoneIdentifier
    {}
  end

  # Only the referrer host and the three UTM values are kept, each cut to UTM_LIMIT characters.
  def sanitize_arrival(arrival)
    arrival = arrival.to_h.stringify_keys
    host = arrival['referrer_host'].to_s.strip.downcase
    utm = UTM_KEYS.index_with { |key| sanitize_utm(arrival[key]) }
    { 'referrer_host' => (host if host.length <= HOST_LIMIT && host.match?(HOST_PATTERN)), **utm }.compact
  end

  def sanitize_utm(value)
    value.to_s.gsub(/[[:cntrl:]]/, '').strip.first(UTM_LIMIT).presence
  end

  # Page metadata is visitor supplied. Keep credentials, queries and fragments out of storage and AI context.
  def sanitize_url(value)
    return unless value.is_a?(String) && value.present? && value.length <= URL_LIMIT

    uri = URI.parse(value)
    return unless uri.is_a?(URI::HTTP) && uri.host.present?

    uri.user = nil
    uri.password = nil
    uri.query = nil
    uri.fragment = nil
    uri.to_s
  rescue URI::InvalidURIError
    nil
  end

  def updated_history(activity, page)
    history = activity.fetch('recent_pages', [])
    if history.last&.fetch('url') == page['url']
      page['visited_at'] = history.last['visited_at']
      history = history[0...-1]
    end
    (history + [page.except('last_seen_at')]).last(HISTORY_LIMIT)
  end
end

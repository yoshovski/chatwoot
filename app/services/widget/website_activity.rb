class Widget::WebsiteActivity
  HISTORY_LIMIT = 50
  TITLE_LIMIT = 200
  URL_LIMIT = 2048

  def initialize(contact_inbox)
    @contact_inbox = contact_inbox
  end

  def record!(url:, title:, browser:, browser_language:)
    page_url = sanitize_url(url)
    return if page_url.blank?

    @contact_inbox.with_lock do
      activity = @contact_inbox.website_activity
      now = Time.current.iso8601(6)
      page = { 'url' => page_url, 'title' => title.to_s.truncate(TITLE_LIMIT), 'last_seen_at' => now, 'visited_at' => now }
      history = updated_history(activity, page)
      @contact_inbox.update!(website_activity: {
                               browser: browser,
                               browser_language: browser_language,
                               current_page: page,
                               recent_pages: history
                             })
    end
    ActiveRecord.after_all_transactions_commit do
      Rails.configuration.dispatcher.dispatch('website_activity.updated', Time.zone.now, contact_inbox: @contact_inbox)
    end
  end

  private

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

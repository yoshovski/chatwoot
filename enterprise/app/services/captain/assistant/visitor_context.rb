class Captain::Assistant::VisitorContext
  RECENT_PAGES_LIMIT = 5

  def self.from_state(state)
    state = state.with_indifferent_access
    activity = state[:website_activity] || {}
    attributes = state.dig(:conversation, :additional_attributes) || {}
    context = {
      browser: activity[:browser].presence || attributes[:browser],
      browser_language: activity[:browser_language].presence || attributes[:browser_language],
      current_page: activity[:current_page],
      recent_pages: Array(activity[:recent_pages]).last(RECENT_PAGES_LIMIT)
    }.compact_blank
    context.presence
  end
end

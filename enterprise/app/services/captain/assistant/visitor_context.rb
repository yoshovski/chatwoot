# Detected context about the visitor for both reply prompts: browser, pages, approximate location, local time, earlier
# visits and how they arrived. Location is detected like the browser, so it does not depend on feature_contact_attributes.
# IP addresses never reach the prompt.
class Captain::Assistant::VisitorContext
  RECENT_PAGES_LIMIT = 5
  ARRIVAL_KEYS = %w[referrer_host utm_source utm_medium utm_campaign].freeze

  def self.from_state(state)
    state = state.with_indifferent_access
    activity = state[:website_activity] || {}
    attributes = state.dig(:conversation, :additional_attributes) || {}
    context = {
      browser: activity[:browser].presence || attributes[:browser],
      browser_language: activity[:browser_language].presence || attributes[:browser_language],
      current_page: activity[:current_page],
      recent_pages: Array(activity[:recent_pages]).last(RECENT_PAGES_LIMIT),
      location: location(state.dig(:contact, :additional_attributes) || {}),
      local_time: local_time(activity[:timezone]),
      returning: returning(activity, state[:visitor_history] || {}),
      arrival: activity.fetch(:arrival, {}).slice(*ARRIVAL_KEYS)
    }.compact_blank
    context.presence
  end

  def self.location(contact_attributes)
    contact_attributes.values_at(:city, :country).compact_blank.join(', ').presence
  end

  def self.local_time(timezone)
    return if timezone.blank?

    Time.current.in_time_zone(TZInfo::Timezone.get(timezone)).strftime('%A %H:%M (%Z)')
  rescue TZInfo::InvalidTimezoneIdentifier
    nil
  end

  # Only for a visitor who came back: a later visit or an earlier conversation in this inbox.
  def self.returning(activity, history)
    visits = activity[:visit_count].to_i
    earlier = history[:earlier_conversations].to_i
    return unless visits > 1 || earlier.positive?

    { visit: visits.positive? ? visits.ordinalize : nil, earlier_conversations: earlier,
      last_conversation_status: history[:last_conversation_status], first_seen_on: activity[:first_seen_at]&.first(10) }.compact
  end

  private_class_method :location, :local_time, :returning
end

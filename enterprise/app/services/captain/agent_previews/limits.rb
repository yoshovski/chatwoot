# Abuse limits of the public agent preview (T27). Each check counts the attempt, so a refused request still uses up
# its place: 3 previews per visitor IP a day, 3 messages per preview, and a global daily budget for website reads and
# for preview messages, which caps the AI cost of the whole feature whatever the traffic.
class Captain::AgentPreviews::Limits
  PREVIEWS_PER_IP = 3
  MESSAGES_PER_PREVIEW = 3

  class << self
    def preview_allowed_for_ip?(ip)
      within?("agent_preview:ip:#{Digest::SHA256.hexdigest(ip.to_s)}:#{today}", PREVIEWS_PER_IP, 1.day)
    end

    # A website read that is not served from the 24-hour cache.
    def read_allowed?
      within?("agent_preview:budget:reads:#{today}", daily_reads, 1.day)
    end

    # Returns the messages left after this one, or nil when the preview or the day has none left.
    def message_allowed?(token)
      count = increment("agent_preview:#{token}:messages", Captain::AgentPreviews::Store::PREVIEW_TTL)
      return if count > MESSAGES_PER_PREVIEW
      return unless within?("agent_preview:budget:messages:#{today}", daily_messages, 1.day)

      MESSAGES_PER_PREVIEW - count
    end

    # At most this many website reads at once: each holds a web thread for up to ~20 s, and the app's other requests
    # (dashboard, widgets) share those threads. Yields, or returns :busy when the slots are taken.
    def reading
      key = 'agent_preview:reading'
      count = increment(key, 1.minute)
      return :busy if count > concurrent_reads

      yield
    ensure
      $alfred.with { |conn| conn.decr(key) } if count # rubocop:disable Style/GlobalVars
    end

    def messages_left(token)
      [MESSAGES_PER_PREVIEW - Redis::Alfred.get("agent_preview:#{token}:messages").to_i, 0].max
    end

    private

    def within?(key, limit, period) = increment(key, period) <= limit

    def increment(key, period)
      count = Redis::Alfred.incr(key)
      Redis::Alfred.expire(key, period.to_i) if count == 1
      count
    end

    def today = Time.current.utc.to_date.iso8601

    def daily_reads = ENV.fetch('AGENT_PREVIEW_DAILY_READS', 300).to_i

    def daily_messages = ENV.fetch('AGENT_PREVIEW_DAILY_MESSAGES', 1000).to_i

    def concurrent_reads = ENV.fetch('AGENT_PREVIEW_CONCURRENT_READS', 2).to_i
  end
end

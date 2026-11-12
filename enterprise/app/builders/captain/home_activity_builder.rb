# How the AI agent did over the last 7 or 30 days, compared with the period before, for the Home page.
# Account-wide: a fixed number of grouped queries, whatever the number of AI agents.
#
# The current period is the last `period` calendar days in the viewer's time zone, today included; the previous
# period is the `period` days before it. Every metric returns its current value, the previous one and one point per day.
class Captain::HomeActivityBuilder
  include TimezoneHelper

  PERIODS = [7, 30].freeze
  TOPIC_LIMIT = 5
  ASSISTANT_SENDER = 'Captain::Assistant'.freeze
  RESOLVED_EVENTS = Captain::AssistantStatsBuilder::RESOLVED_EVENT_NAMES
  HANDOFF_EVENTS = Captain::AssistantStatsBuilder::HANDOFF_EVENT_NAMES
  BOT_RESOLVED_EVENT = Captain::AssistantStatsBuilder::BOT_RESOLVED_EVENT_NAME
  PRODUCT_SOURCE_USED = [{ kind: 'product', used: true }].to_json.freeze

  def initialize(account, period:, timezone_offset: nil)
    @account = account
    @period = period
    @zone = ActiveSupport::TimeZone[timezone_name_from_offset(timezone_offset)] || Time.zone
  end

  def activity
    {
      period: period,
      metrics: metrics,
      days: dates.zip(points(:ai), points(:team)).map { |date, ai, team| { date: date.iso8601, ai: ai, team: team } },
      topics: topics
    }
  end

  private

  attr_reader :account, :period, :zone

  def metrics
    {
      ai_conversations: metric(*totals[:ai], points(:ai)),
      resolved: metric(*totals[:resolved].zip(totals[:ai]).map { |pair| rate(*pair) }, points(:resolved).zip(points(:ai)).map { |pair| rate(*pair) }),
      handed: metric(*totals[:handed], points(:handed)),
      rating: rating_metric,
      product_answers: product_answers_metric
    }
  end

  # One number per day of the current period from the daily counts (:ai, :team, :resolved or :handed).
  def points(key)
    @daily ||= daily_messages.merge(daily_events) { |_, messages, events| messages.merge(events) }
    dates.map { |date| @daily.dig(date, key).to_i }
  end

  # Conversations where the AI agent answered from a product (it can't see orders yet, so this is not "sales").
  def product_answers_metric
    sessions = account.captain_agent_sessions.session_assistant.where(subject_type: 'Conversation', created_at: full_span)
                      .where('sources @> ?', PRODUCT_SOURCE_USED).reorder(nil)
    daily = sessions.where(created_at: current_range).group(Arel.sql(day_sql)).distinct.count(:subject_id)
    metric(*sessions.pick(*window_counts('subject_id')), dates.map { |date| daily[date].to_i })
  end

  def window_counts(column)
    [current_range, previous_range].map { |range| Arel.sql("COUNT(DISTINCT #{column}) FILTER (WHERE #{in_window(range)})") }
  end

  def metric(current, previous, points)
    { value: current, previous: previous, points: points }
  end

  # Window totals count each conversation once, so they come from FILTER aggregates rather than summed days.
  def totals
    @totals ||= begin
      ai = ai_messages.where(created_at: full_span).reorder(nil).pick(*window_counts('conversation_id'))
      events = ai_events(full_span).reorder(nil).pick(*event_totals_projections)
      { ai: ai, resolved: events.first(2), handed: events.last(2) }
    end
  end

  # Resolved in the current and previous period, then handed in the current and previous period.
  def event_totals_projections
    [[resolved_clause, current_range], [resolved_clause, previous_range], [handoff_clause, current_range], [handoff_clause, previous_range]]
      .map { |clause, range| Arel.sql("COUNT(DISTINCT conversation_id) FILTER (WHERE #{clause} AND #{in_window(range)})") }
  end

  # { date => { ai:, team: } }: conversations the AI agent answered in, and conversations a person replied in.
  def daily_messages
    account.messages.where(created_at: current_range).reorder(nil).group(Arel.sql(day_sql))
           .pluck(Arel.sql(day_sql),
                  Arel.sql("COUNT(DISTINCT conversation_id) FILTER (WHERE sender_type = '#{ASSISTANT_SENDER}')"),
                  Arel.sql("COUNT(DISTINCT conversation_id) FILTER (WHERE #{team_reply_clause})"))
           .to_h { |date, ai, team| [date, { ai: ai, team: team }] }
  end

  def daily_events
    ai_events(current_range).reorder(nil).group(Arel.sql(day_sql))
                            .pluck(Arel.sql(day_sql),
                                   Arel.sql("COUNT(DISTINCT conversation_id) FILTER (WHERE #{resolved_clause})"),
                                   Arel.sql("COUNT(DISTINCT conversation_id) FILTER (WHERE #{handoff_clause})"))
                            .to_h { |date, resolved, handed| [date, { resolved: resolved, handed: handed }] }
  end

  # Customer ratings (1 to 5). Sums and counts add up across days, so one grouped query gives both windows and the points.
  def rating_metric
    rows = daily_ratings
    current, previous = rows.partition { |date, _| date >= dates.first }.map { |pairs| average(pairs.map(&:last)) }
    metric(current, previous, dates.map { |date| rows[date] && average([rows[date]]) })
  end

  # { date => [sum of ratings, count] } over both periods.
  def daily_ratings
    account.csat_survey_responses.where(created_at: full_span).reorder(nil).group(Arel.sql(day_sql))
           .pluck(Arel.sql(day_sql), Arel.sql('SUM(rating)'), Arel.sql('COUNT(*)')).to_h { |date, sum, count| [date, [sum, count]] }
  end

  def average(sums_and_counts)
    count = sums_and_counts.sum(&:last)
    count.zero? ? nil : (sums_and_counts.sum(&:first).to_f / count).round(1)
  end

  # The most used conversation labels in the current period, until conversations get a topic of their own.
  def topics
    conversation_ids = account.conversations.where(created_at: current_range).select(:id)
    ActsAsTaggableOn::Tagging.joins(:tag).where(taggable_type: 'Conversation', context: 'labels', taggable_id: conversation_ids)
                             .group('tags.name').order(Arel.sql('COUNT(*) DESC'), 'tags.name').limit(TOPIC_LIMIT).count
                             .map { |label, count| { label: label, count: count } }
  end

  def ai_messages
    account.messages.where(sender_type: ASSISTANT_SENDER)
  end

  # Resolve and handoff events of conversations the AI agent answered in.
  def ai_events(range)
    account.reporting_events.where(name: RESOLVED_EVENTS + HANDOFF_EVENTS, created_at: range,
                                   conversation_id: ai_messages.where(created_at: full_span).select(:conversation_id))
  end

  # As on the AI agent Overview: a bot resolve after a handoff is the team's work, not the AI agent's.
  def resolved_clause
    @resolved_clause ||= begin
      handed_off = account.reporting_events.where(name: HANDOFF_EVENTS, created_at: full_span).select(:conversation_id).to_sql
      "name IN (#{quoted(RESOLVED_EVENTS)}) AND NOT (name = #{quote(BOT_RESOLVED_EVENT)} AND conversation_id IN (#{handed_off}))"
    end
  end

  def handoff_clause
    "name IN (#{quoted(HANDOFF_EVENTS)})"
  end

  def team_reply_clause
    "sender_type = 'User' AND message_type = #{Message.message_types[:outgoing]} AND private = false"
  end

  def dates
    @dates ||= (0...period).map { |offset| today - (period - 1 - offset) }
  end

  def today
    @today ||= Time.current.in_time_zone(zone).to_date
  end

  def current_range
    @current_range ||= zone.local(dates.first.year, dates.first.month, dates.first.day)..Time.current
  end

  def previous_range
    @previous_range ||= (current_range.first - period.days)...current_range.first
  end

  def full_span
    previous_range.first..current_range.last
  end

  # The viewer's calendar day of a stored UTC timestamp.
  def day_sql
    "DATE((created_at AT TIME ZONE 'UTC') AT TIME ZONE #{quote(zone.tzinfo.name)})"
  end

  def in_window(range)
    operator = range.exclude_end? ? '<' : '<='
    "created_at >= #{quote(range.first)} AND created_at #{operator} #{quote(range.last)}"
  end

  def rate(numerator, denominator)
    denominator.zero? ? 0 : (numerator.to_f / denominator * 100).round
  end

  def quote(value)
    account.class.connection.quote(value)
  end

  def quoted(values)
    values.map { |value| quote(value) }.join(', ')
  end
end

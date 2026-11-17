class Api::V1::Accounts::Captain::HomeController < Api::V1::Accounts::BaseController
  PERIODS = Captain::HomeActivityBuilder::PERIODS
  MAX_RANGE_DAYS = 90

  def show
    period = params[:period].present? ? Integer(params[:period], exception: false) : PERIODS.first
    return render_could_not_create_error("period must be one of #{PERIODS.join(', ')}") unless PERIODS.include?(period)

    range = params[:range]
    if range.present? && Captain::AssistantStatsWindow::ALLOWED_RANGES.exclude?(range)
      return render_could_not_create_error('Unsupported report range')
    end

    window = dashboard_window
    return render_could_not_create_error('Select a valid date range of up to 90 days') unless window

    render json: Captain::HomeSummaryBuilder.new(Current.account, Current.user, period: period, timezone_offset: params[:timezone_offset],
                                                                                range: range, **window).summary
  end

  def live
    needs = Captain::HomeNeedsBuilder.new(Current.account, Current.user)
    render json: { open_conversations: needs.open_conversation_count, live_visitors: live_visitor_count }
  end

  private

  def dashboard_window
    return {} if params.values_at(:start_date, :end_date).all?(&:nil?)
    return if params[:range].present?

    zone = Time.find_zone(params[:time_zone].to_s)
    dates = dashboard_dates
    return unless zone && dates && dates.last <= zone.today

    { calendar: { dates: dates, zone: zone } }
  end

  def dashboard_dates
    from, to = params.values_at(:start_date, :end_date).map { |value| dashboard_date(value.to_s) }
    (from..to) if from && to && (0...MAX_RANGE_DAYS).cover?(to - from)
  end

  def dashboard_date(value)
    Date.iso8601(value) if value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
  rescue Date::Error
    nil
  end

  def live_visitor_count
    return unless policy(Contact).active?

    Contacts::Segments.new(Current.account, Current.user).scope('online').count
  rescue Redis::BaseError
    nil
  end
end

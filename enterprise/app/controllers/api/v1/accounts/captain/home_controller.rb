class Api::V1::Accounts::Captain::HomeController < Api::V1::Accounts::BaseController
  PERIODS = Captain::HomeActivityBuilder::PERIODS

  def show
    period = params[:period].present? ? Integer(params[:period], exception: false) : PERIODS.first
    return render_could_not_create_error("period must be one of #{PERIODS.join(', ')}") unless PERIODS.include?(period)

    render json: Captain::HomeSummaryBuilder.new(Current.account, Current.user, period: period, timezone_offset: params[:timezone_offset]).summary
  end
end

class Api::V1::Accounts::Captain::HomeController < Api::V1::Accounts::BaseController
  def show
    render json: Captain::HomeSummaryBuilder.new(Current.account, Current.user).summary
  end
end

# Renders a shareable page with one inbox's widget already open, for showing the assistant to a
# prospective client. The website token is public -- it sits in every embed snippet -- so the page
# is gated on the inbox having demo mode switched on rather than on the token being secret.
class DemosController < ActionController::Base
  before_action :set_web_widget

  def show
    # `?open=false` leaves the widget closed and the bubble visible, which is how a campaign's
    # proactive message and its reply suggestions get demoed.
    @open_on_load = params[:open] != 'false'
  end

  private

  def set_web_widget
    @web_widget = ::Channel::WebWidget.find_by!(
      website_token: params[:website_token],
      demo_mode_enabled: true
    )
    @inbox = @web_widget.inbox
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end
end

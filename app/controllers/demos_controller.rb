# Renders a shareable page with one inbox's widget already open, for showing the assistant to a
# prospective client. The website token is public -- it sits in every embed snippet -- so the page
# is gated on the inbox having demo mode switched on rather than on the token being secret.
class DemosController < ActionController::Base
  before_action :set_web_widget

  def show
    # `?open=false` leaves the widget closed, which is how a campaign's proactive message and its
    # reply suggestions get demoed.
    @open_on_load = params[:open] != 'false'
  end

  private

  # The slug is what gets sent to a client; the website token keeps working so a demo can be
  # shared the moment the switch is flipped, without having to name it first.
  def set_web_widget
    demos = ::Channel::WebWidget.where(demo_mode_enabled: true)
    @web_widget = demos.find_by(demo_slug: params[:id]) || demos.find_by(website_token: params[:id])
    return head :not_found if @web_widget.blank?

    @inbox = @web_widget.inbox
  end
end

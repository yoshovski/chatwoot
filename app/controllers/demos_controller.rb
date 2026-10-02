# Renders a shareable page with one inbox's widget already open, for showing the assistant to a
# prospective client. The website token is public -- it sits in every embed snippet -- so the page
# is gated on the inbox having demo mode switched on rather than on the token being secret.
class DemosController < ActionController::Base
  # Above this the widget colour is treated as light, matching isWidgetColorLighter in the widget.
  LIGHT_WIDGET_BRIGHTNESS = 225

  before_action :set_global_config
  before_action :set_web_widget

  def show
    # `?open=false` leaves the widget closed, which is how a campaign's proactive message and its
    # reply suggestions get demoed.
    @open_on_load = params[:open] != 'false'
  end

  private

  def set_global_config
    @global_config = GlobalConfig.get('BRAND_NAME', 'INSTALLATION_NAME', 'WIDGET_BRAND_URL')
  end

  # The slug is what gets sent to a client; the website token keeps working so a demo can be
  # shared the moment the switch is flipped, without having to name it first.
  def set_web_widget
    demos = ::Channel::WebWidget.where(demo_mode_enabled: true)
    @web_widget = demos.find_by(demo_slug: params[:id]) || demos.find_by(website_token: params[:id])
    return head :not_found if @web_widget.blank?

    @inbox = @web_widget.inbox
    @account = @web_widget.account
    # The backdrop is one fixed design; the widget colour only picks which side of it to show, so
    # that the launcher and the message bubbles always have something to read against.
    @backdrop = light_widget_color? ? 'dark' : 'light'
  end

  def light_widget_color?
    hex = @web_widget.widget_color.to_s[/\A#((?:[0-9a-f]{3}|[0-9a-f]{6}))\z/i, 1]
    return true if hex.blank?

    hex = hex.chars.flat_map { |char| [char, char] }.join if hex.length == 3
    red, green, blue = hex.scan(/../).map { |pair| pair.to_i(16) }
    (((red * 299) + (green * 587) + (blue * 114)) / 1000) > LIGHT_WIDGET_BRIGHTNESS
  end
end

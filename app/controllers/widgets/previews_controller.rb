# The real widget page in preview mode, framed by the inbox settings page. It loads with a signed preview token
# instead of a visitor session, so opening the settings never creates a contact, contact inbox, conversation or visit.
class Widgets::PreviewsController < WidgetsController
  skip_before_action :set_token, :set_contact, :build_contact

  def show
    @preview = true
    @preview_agent_name = @web_widget.inbox.try(:captain_assistant)&.name
    render 'widgets/show'
  end

  private

  def set_web_widget
    payload = Widget::PreviewToken.verify(params[:token])
    return head :unauthorized unless payload

    @web_widget = Inbox.find_by(id: payload[:inbox_id])&.channel
    head :not_found unless @web_widget.is_a?(Channel::WebWidget)
  end

  # Visitor location rules apply to visitors, not to the admin previewing the widget.
  def ensure_location_is_supported; end

  # Only the dashboard, served from the same origin, may frame the preview.
  def allow_iframe_requests
    response.headers['X-Frame-Options'] = 'SAMEORIGIN'
    response.headers['Content-Security-Policy'] = "frame-ancestors 'self'"
  end
end

class Api::V1::Widget::WebsiteActivityController < Api::V1::Widget::BaseController
  def create
    page = params[:page]
    return head :unprocessable_entity unless valid_page?(page)

    # Browsing is recorded only after this visitor has interacted with the chat.
    if conversations.joins(:messages).exists?(messages: { message_type: :incoming })
      ::Widget::WebsiteActivity.new(conversation.contact_inbox).record!(url: page[:url], title: page[:title], browser: browser_params,
                                                                        browser_language: browser.accept_language&.first&.code,
                                                                        visit: visit_params)
    end
    head :no_content
  end

  private

  # How the visitor arrived and their browser time zone, sent by the widget with every page view it posts.
  def visit_params
    visit = params.permit(visit: %i[timezone referrer_host utm_source utm_medium utm_campaign])[:visit].to_h
    { arrival: visit.except(:timezone), timezone: visit[:timezone] }
  end

  def valid_page?(page)
    page.is_a?(ActionController::Parameters) && page[:url].is_a?(String) && (page[:title].nil? || page[:title].is_a?(String))
  end
end

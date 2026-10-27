class Api::V1::Accounts::Conversations::WebsiteActivityController < Api::V1::Accounts::Conversations::BaseController
  def show
    render json: {
      contact_inbox_id: @conversation.contact_inbox_id,
      activity: @conversation.contact_inbox&.website_activity || {}
    }
  end
end

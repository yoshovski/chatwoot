class Api::V1::Accounts::Hubspot::AuthorizationsController < Api::V1::Accounts::OauthAuthorizationController
  def create
    render json: { success: true, url: Crm::Hubspot::OauthClient.new.authorize_url(state) }
  end
end

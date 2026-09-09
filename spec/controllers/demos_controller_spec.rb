require 'rails_helper'

describe '/demo', type: :request do
  let(:web_widget) { create(:channel_widget, demo_mode_enabled: true) }

  describe 'GET /demo/:website_token' do
    it 'renders the demo page when demo mode is enabled' do
      get "/demo/#{web_widget.website_token}"

      expect(response).to be_successful
      expect(response.body).to include(web_widget.website_token)
    end

    it 'returns not found when demo mode is disabled' do
      disabled_widget = create(:channel_widget)

      get "/demo/#{disabled_widget.website_token}"

      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found for an unknown website token' do
      get '/demo/not-a-real-token'

      expect(response).to have_http_status(:not_found)
    end
  end
end

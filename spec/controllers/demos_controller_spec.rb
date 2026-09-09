require 'rails_helper'

describe '/demo', type: :request do
  let(:web_widget) { create(:channel_widget, demo_mode_enabled: true) }

  describe 'GET /demo/:id' do
    it 'renders the demo page for the website token when demo mode is enabled' do
      get "/demo/#{web_widget.website_token}"

      expect(response).to be_successful
      expect(response.body).to include(web_widget.website_token)
    end

    it 'renders the demo page for the demo slug' do
      web_widget.update!(demo_slug: 'scanixx-website')

      get '/demo/scanixx-website'

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

    it 'shows the account name and takes the backdrop that contrasts with the widget colour' do
      web_widget.account.update!(name: 'Scanixx')
      web_widget.update!(widget_color: '#ffffff')

      get "/demo/#{web_widget.website_token}"

      expect(response.body).to include('Scanixx')
      expect(response.body).to include('backdrop-dark')
    end

    it 'takes the light backdrop for a dark widget colour' do
      web_widget.update!(widget_color: '#111827')

      get "/demo/#{web_widget.website_token}"

      expect(response.body).to include('backdrop-light')
    end
  end
end

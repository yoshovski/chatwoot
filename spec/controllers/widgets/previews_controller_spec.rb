require 'rails_helper'

describe '/widget/preview', type: :request do
  let(:account) { create(:account) }
  let(:web_widget) { create(:channel_widget, account: account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:token) { Widget::PreviewToken.generate(inbox: web_widget.inbox, user: admin)[:token] }

  it 'renders the widget in preview mode' do
    get widget_preview_url(token: token)

    expect(response).to be_successful
    expect(response.body).to include('preview: true')
    expect(response.body).to include(web_widget.website_token)
  end

  it 'creates no contact, contact inbox or conversation' do
    token

    expect do
      get widget_preview_url(token: token)
    end.not_to(change { [Contact.count, ContactInbox.count, Conversation.count] })
    expect(response).to be_successful
  end

  it 'only lets the app itself frame the page' do
    get widget_preview_url(token: token)

    expect(response.headers['X-Frame-Options']).to eq('SAMEORIGIN')
    expect(response.headers['Content-Security-Policy']).to eq("frame-ancestors 'self'")
  end

  it 'keeps the frame headers when the inbox allows other domains' do
    web_widget.update!(allowed_domains: 'example.com')

    get widget_preview_url(token: token)

    expect(response.headers['Content-Security-Policy']).to eq("frame-ancestors 'self'")
  end

  it 'rejects a missing token' do
    get widget_preview_url

    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects an expired token' do
    token

    travel 16.minutes do
      get widget_preview_url(token: token)
    end

    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects a tampered token' do
    tampered = token.end_with?('a') ? "#{token.chop}b" : "#{token.chop}a"

    get widget_preview_url(token: tampered)

    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects a token signed for another purpose' do
    other_token = Rails.application.message_verifier(:widget_preview).generate({ inbox_id: web_widget.inbox.id })

    get widget_preview_url(token: other_token)

    expect(response).to have_http_status(:unauthorized)
  end

  it 'returns 401 if the account is suspended' do
    token
    account.update!(status: :suspended)

    get widget_preview_url(token: token)

    expect(response).to have_http_status(:unauthorized)
  end
end

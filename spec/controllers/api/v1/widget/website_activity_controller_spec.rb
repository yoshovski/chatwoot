require 'rails_helper'

RSpec.describe '/api/v1/widget/website_activity', type: :request do
  let(:account) { create(:account) }
  let(:web_widget) { create(:channel_widget, account: account) }
  let(:contact) { create(:contact, account: account, email: nil) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: web_widget.inbox) }
  let!(:conversation) { create(:conversation, contact: contact, account: account, inbox: web_widget.inbox, contact_inbox: contact_inbox) }
  let(:token) { Widget::TokenService.new(payload: { source_id: contact_inbox.source_id, inbox_id: web_widget.inbox.id }).generate_token }
  let(:params) do
    { website_token: web_widget.website_token, page: { url: 'https://shop.example.com/plans?utm_campaign=spring', title: 'Plans' },
      visit: { timezone: 'Europe/Madrid', referrer_host: 'www.google.com', utm_campaign: 'spring' } }
  end

  it 'records nothing before the first visitor message' do
    create(:message, conversation: conversation, message_type: :outgoing)
    post api_v1_widget_website_activity_url, params: params, headers: { 'X-Auth-Token' => token }, as: :json

    expect(response).to have_http_status(:no_content)
    expect(contact_inbox.reload.website_activity).to eq({})
  end

  it 'records the page with the arrival and time zone after the first visitor message' do
    create(:message, conversation: conversation, message_type: :incoming)
    post api_v1_widget_website_activity_url, params: params, headers: { 'X-Auth-Token' => token }, as: :json

    expect(response).to have_http_status(:no_content)
    activity = contact_inbox.reload.website_activity
    expect(activity['current_page']['url']).to eq('https://shop.example.com/plans')
    expect(activity['timezone']).to eq('Europe/Madrid')
    expect(activity['arrival']).to include('referrer_host' => 'www.google.com', 'utm_campaign' => 'spring')
  end

  it 'records the page without visit data' do
    create(:message, conversation: conversation, message_type: :incoming)
    post api_v1_widget_website_activity_url, params: params.except(:visit), headers: { 'X-Auth-Token' => token }, as: :json

    expect(response).to have_http_status(:no_content)
    expect(contact_inbox.reload.website_activity['visit_count']).to eq(1)
  end
end

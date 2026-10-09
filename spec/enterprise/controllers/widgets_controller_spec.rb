require 'rails_helper'

describe '/widget', type: :request do
  let(:account) { create(:account) }
  let(:web_widget) { create(:channel_widget, account: account) }
  let(:assistant) { create(:captain_assistant, account: account, name: 'Luna') }

  it 'tells the widget which AI agent answers in the inbox' do
    create(:captain_inbox, captain_assistant: assistant, inbox: web_widget.inbox)

    get widget_url(website_token: web_widget.website_token)

    expect(response.body).to include('captainAssistant: {"name":"Luna"}')
  end

  it 'sends no AI agent when the inbox has none' do
    get widget_url(website_token: web_widget.website_token)

    expect(response.body).to include('captainAssistant: null')
  end
end

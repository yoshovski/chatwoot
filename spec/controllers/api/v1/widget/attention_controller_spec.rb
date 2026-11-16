require 'rails_helper'

RSpec.describe '/api/v1/widget/attention', type: :request do
  let(:account) { create(:account) }
  let(:web_widget) { create(:channel_widget, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: web_widget.inbox) }
  let(:payload) { { source_id: contact_inbox.source_id, inbox_id: web_widget.inbox.id } }
  let(:token) { Widget::TokenService.new(payload: payload).generate_token }
  let(:path) { "/api/v1/widget/attention?website_token=#{web_widget.website_token}" }

  def post_attention(params) = post(path, params: params, headers: { 'X-Auth-Token' => token }, as: :json)

  it 'rejects an unknown kind' do
    post_attention(kind: 'confetti')

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'rejects a message id that is not an integer' do
    post_attention(kind: 'sound', message_id: '12')

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'returns no content without a conversation' do
    post_attention(kind: 'activity')

    expect(response).to have_http_status(:no_content)
  end

  it 'returns the grant for a sound on the latest reply' do
    conversation = create(:conversation, account: account, inbox: web_widget.inbox, contact: contact, contact_inbox: contact_inbox)
    reply = create(:message, conversation: conversation, account: account, inbox: web_widget.inbox, message_type: :outgoing)

    post_attention(kind: 'sound', message_id: reply.id)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('kind' => 'sound', 'message_id' => reply.id)
  end
end

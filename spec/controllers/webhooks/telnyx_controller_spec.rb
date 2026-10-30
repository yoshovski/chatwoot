require 'rails_helper'

RSpec.describe 'Webhooks::TelnyxController', type: :request do
  let!(:channel) { create(:channel_sms, :telnyx, phone_number: '+15550001111') }
  let(:payload) do
    { data: { event_type: 'message.received',
              payload: { id: 'msg-1', from: { phone_number: '+15559998888' }, to: [{ phone_number: '+15550001111' }], text: 'hi' } } }
  end

  before { allow(Webhooks::TelnyxEventsJob).to receive(:perform_later) }

  it 'enqueues the event for a known Telnyx number' do
    post '/webhooks/telnyx', params: payload, as: :json

    expect(response).to have_http_status(:ok)
    expect(Webhooks::TelnyxEventsJob).to have_received(:perform_later).with(hash_including('data'))
  end

  it 'acknowledges but ignores events for unknown numbers' do
    payload[:data][:payload][:to] = [{ phone_number: '+10000000000' }]
    post '/webhooks/telnyx', params: payload, as: :json

    expect(response).to have_http_status(:ok)
    expect(Webhooks::TelnyxEventsJob).not_to have_received(:perform_later)
  end

  context 'when the inbox has a webhook public key' do
    let(:signing_key) { OpenSSL::PKey.generate_key('ED25519') }

    before do
      channel.update!(provider_config: channel.provider_config.merge('public_key' => Base64.strict_encode64(signing_key.raw_public_key)))
    end

    it 'rejects unsigned requests' do
      post '/webhooks/telnyx', params: payload, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(Webhooks::TelnyxEventsJob).not_to have_received(:perform_later)
    end

    it 'accepts correctly signed requests' do
      body = payload.to_json
      timestamp = Time.zone.now.to_i.to_s
      signature = Base64.strict_encode64(signing_key.sign(nil, "#{timestamp}|#{body}"))

      post '/webhooks/telnyx', params: body, headers: { 'Content-Type' => 'application/json', 'telnyx-timestamp' => timestamp,
                                                        'telnyx-signature-ed25519' => signature }

      expect(response).to have_http_status(:ok)
      expect(Webhooks::TelnyxEventsJob).to have_received(:perform_later)
    end
  end
end

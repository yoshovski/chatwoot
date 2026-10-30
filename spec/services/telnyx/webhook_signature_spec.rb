require 'rails_helper'

describe Telnyx::WebhookSignature do
  let(:signing_key) { OpenSSL::PKey.generate_key('ED25519') }
  let(:public_key) { Base64.strict_encode64(signing_key.raw_public_key) }
  let(:body) { '{"data":{"event_type":"message.received"}}' }
  let(:timestamp) { Time.zone.now.to_i.to_s }
  let(:signature) { Base64.strict_encode64(signing_key.sign(nil, "#{timestamp}|#{body}")) }

  describe '.valid?' do
    it 'accepts a payload signed with the matching key' do
      expect(described_class.valid?(public_key: public_key, signature: signature, timestamp: timestamp, body: body)).to be true
    end

    it 'rejects a tampered body' do
      expect(described_class.valid?(public_key: public_key, signature: signature, timestamp: timestamp, body: "#{body} ")).to be false
    end

    it 'rejects a stale timestamp' do
      old = 10.minutes.ago.to_i.to_s
      old_signature = Base64.strict_encode64(signing_key.sign(nil, "#{old}|#{body}"))
      expect(described_class.valid?(public_key: public_key, signature: old_signature, timestamp: old, body: body)).to be false
    end

    it 'rejects garbage keys instead of raising' do
      expect(described_class.valid?(public_key: 'bm90LWEta2V5', signature: signature, timestamp: timestamp, body: body)).to be false
    end
  end
end

require 'rails_helper'

describe Sms::Providers::TelnyxService do
  let(:channel) { create(:channel_sms, :telnyx, phone_number: '+15550001111') }
  let(:conversation) { create(:conversation, inbox: channel.inbox) }
  let(:message) { create(:message, conversation: conversation, message_type: :outgoing, content: 'Hello there') }

  describe '#send_message' do
    it 'posts the message to Telnyx and returns its id' do
      stub = stub_request(:post, 'https://api.telnyx.com/v2/messages')
             .with(
               headers: { 'Authorization' => 'Bearer KEYtest' },
               body: hash_including('from' => '+15550001111', 'to' => '+15559998888', 'text' => 'Hello there',
                                    'messaging_profile_id' => 'mp-1')
             )
             .to_return(status: 200, body: { data: { id: 'msg-123' } }.to_json, headers: { 'Content-Type' => 'application/json' })

      expect(channel.send_message('+15559998888', message)).to eq('msg-123')
      expect(stub).to have_been_requested
    end

    it 'sends attachments as media_urls' do
      attachment = message.attachments.new(account_id: message.account_id, file_type: :image)
      attachment.file.attach(io: StringIO.new('img'), filename: 'pic.png', content_type: 'image/png')
      attachment.save!

      stub = stub_request(:post, 'https://api.telnyx.com/v2/messages')
             .with { |request| JSON.parse(request.body)['media_urls'].present? }
             .to_return(status: 200, body: { data: { id: 'msg-124' } }.to_json, headers: { 'Content-Type' => 'application/json' })

      channel.send_message('+15559998888', message.reload)
      expect(stub).to have_been_requested
    end

    it 'marks the message failed with the Telnyx error' do
      stub_request(:post, 'https://api.telnyx.com/v2/messages')
        .to_return(status: 422, body: { errors: [{ code: '40310', title: 'Invalid to number' }] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect(channel.send_message('+1', message)).to be_nil
      expect(message.reload.status).to eq('failed')
      expect(message.external_error).to include('Invalid to number')
    end
  end

  describe 'provider routing' do
    it 'keeps Bandwidth as the default provider' do
      expect(create(:channel_sms).provider_service).to be_a(Sms::Providers::BandwidthService)
    end
  end
end

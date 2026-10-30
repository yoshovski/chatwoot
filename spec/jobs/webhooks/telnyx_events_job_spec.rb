require 'rails_helper'

RSpec.describe Webhooks::TelnyxEventsJob do
  let!(:channel) { create(:channel_sms, :telnyx, phone_number: '+15550001111') }
  let(:inbox) { channel.inbox }

  def event(type, payload)
    { 'data' => { 'event_type' => type, 'payload' => payload } }
  end

  describe 'message.received' do
    let(:payload) do
      { 'id' => 'msg-in-1', 'from' => { 'phone_number' => '+15559998888' }, 'to' => [{ 'phone_number' => '+15550001111' }],
        'text' => 'Hello from Telnyx', 'media' => [] }
    end

    it 'creates an incoming message on a new conversation' do
      described_class.perform_now(event('message.received', payload))

      message = inbox.messages.last
      expect(message.content).to eq('Hello from Telnyx')
      expect(message.source_id).to eq('msg-in-1')
      expect(message.sender.phone_number).to eq('+15559998888')
    end

    it 'ignores a retried delivery of the same message' do
      2.times { described_class.perform_now(event('message.received', payload)) }

      expect(inbox.messages.where(source_id: 'msg-in-1').count).to eq(1)
    end

    it 'attaches MMS media' do
      allow(SafeFetch).to receive(:fetch).and_yield(
        Struct.new(:tempfile, :original_filename, :content_type).new(StringIO.new('jpeg-bytes'), 'pic.jpg', 'image/jpeg')
      )

      described_class.perform_now(event('message.received', payload.merge('media' => [{ 'url' => 'https://media.example.com/pic.jpg' }])))

      expect(inbox.messages.last.attachments.count).to eq(1)
    end
  end

  describe 'delivery receipts' do
    let(:conversation) { create(:conversation, inbox: inbox) }
    let!(:message) { create(:message, conversation: conversation, message_type: :outgoing, source_id: 'msg-out-1') }

    def receipt(type, status, errors = [])
      event(type, { 'id' => 'msg-out-1', 'from' => { 'phone_number' => '+15550001111' },
                    'to' => [{ 'phone_number' => '+15559998888', 'status' => status }], 'errors' => errors })
    end

    it 'marks the message delivered' do
      described_class.perform_now(receipt('message.finalized', 'delivered'))
      expect(message.reload.status).to eq('delivered')
    end

    it 'does not step a delivered message back to sent' do
      message.update!(status: :delivered)
      described_class.perform_now(receipt('message.sent', 'sent'))
      expect(message.reload.status).to eq('delivered')
    end

    it 'records the failure reason' do
      described_class.perform_now(receipt('message.finalized', 'delivery_failed', [{ 'code' => '40008', 'title' => 'Undeliverable' }]))

      expect(message.reload.status).to eq('failed')
      expect(message.external_error).to eq('40008 - Undeliverable')
    end
  end
end

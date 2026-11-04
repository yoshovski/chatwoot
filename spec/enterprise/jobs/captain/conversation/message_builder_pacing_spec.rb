require 'rails_helper'

RSpec.describe Captain::Conversation::MessageBuilder do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:payloads) do
    [{ content: 'Here is the answer.', additional_attributes: { 'captain_segment_kinds' => ['answer'] } },
     { content: 'Anything else?', additional_attributes: { 'captain_segment_kinds' => ['question'] } }]
  end
  let(:builder) do
    test_conversation = conversation
    test_assistant = assistant
    composer = instance_double(Captain::Conversation::ReplyComposer, messages: payloads)
    Class.new do
      include Captain::Conversation::MessageBuilder

      define_method(:initialize) do
        @conversation = test_conversation
        @assistant = test_assistant
      end
      define_method(:reply_composer) { composer }
      define_method(:account) { @conversation.account }
      define_method(:inbox) { @conversation.inbox }
      define_method(:captain_v2_enabled?) { true }
      define_method(:waiting_for_human?) { false }
      define_method(:handoff_active_or_requested?) { false }
      define_method(:responding_to_customer_message) { @conversation.messages.incoming.last }
      public :create_messages
    end.new
  end

  before { create(:message, conversation: conversation, message_type: :incoming, created_at: 10.seconds.ago) }

  context 'with a web widget inbox' do
    let(:inbox) { create(:inbox, account: account, channel: create(:channel_widget, account: account)) }

    it 'stamps one reply id and the reveal offsets on the bubbles' do
      builder.create_messages
      replies = conversation.messages.outgoing.order(:id).map(&:additional_attributes)

      expect(replies.pluck('captain_reply_id').uniq.compact.size).to eq(1)
      expect(replies.pluck('captain_reveal_offset_ms')).to eq([0, Captain::Behaviour.bubble_pause_ms('Anything else?')])
      expect(replies.first).to include('captain_segment_kinds' => ['answer'])
    end

    it 'continues the pacing of the early welcome posted for this message' do
      welcome = create(:message, conversation: conversation, message_type: :outgoing, sender: assistant, content: 'Hi, welcome!',
                                 additional_attributes: { 'captain_segment_kinds' => ['greeting'], 'captain_reply_id' => 'welcome-reply',
                                                          'captain_reveal_offset_ms' => 0 })

      builder.create_messages
      replies = conversation.messages.outgoing.where.not(id: welcome.id).order(:id).map(&:additional_attributes)

      expect(replies.pluck('captain_reply_id')).to eq(%w[welcome-reply welcome-reply])
    end
  end

  context 'with an email inbox' do
    let(:inbox) { create(:inbox, account: account, channel: create(:channel_email, account: account)) }

    it 'posts the payloads unchanged' do
      builder.create_messages

      expect(conversation.messages.outgoing.order(:id).map(&:additional_attributes))
        .to eq([{ 'captain_segment_kinds' => ['answer'] }, { 'captain_segment_kinds' => ['question'] }])
    end
  end
end

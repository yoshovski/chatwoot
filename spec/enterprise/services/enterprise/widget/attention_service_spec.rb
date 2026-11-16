require 'rails_helper'

RSpec.describe Widget::AttentionService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, status: :pending) }
  let(:contact_inbox) { conversation.contact_inbox }

  let(:check_in_writer) { instance_double(Captain::Conversation::CheckInService, generated: nil) }

  before do
    account.enable_features!('captain_integration_v2')
    create(:captain_inbox, inbox: inbox, captain_assistant: assistant)
    allow(Captain::Conversation::CheckInService).to receive(:new).and_return(check_in_writer)
  end

  def service(for_conversation = conversation) = described_class.new(contact_inbox: contact_inbox, conversation: for_conversation)

  def exchange(intent, at: 1.minute.ago, in_conversation: conversation)
    create(:message, conversation: in_conversation, account: account, inbox: inbox, message_type: :incoming,
                     sender: in_conversation.contact, created_at: at - 5.seconds)
    create(:message, conversation: in_conversation, account: account, inbox: inbox, message_type: :outgoing, sender: assistant,
                     created_at: at, additional_attributes: { 'captain_reply_id' => SecureRandom.uuid, 'captain_reply_final' => true,
                                                              'captain_attention_intent' => intent })
  end

  it 'grants the "anything else?" check-in once the answer is complete and quiet long enough' do
    reply = exchange('answer_complete')

    expect(service.perform(kind: 'check_in', message_id: reply.id)).to include(kind: 'check_in', message_id: reply.id)
  end

  it 'adds the check-in the assistant wrote for this conversation' do
    reply = exchange('answer_complete')
    allow(check_in_writer).to receive(:generated).and_return(
      text: 'Want help choosing a battery?',
      suggested_replies: [{ 'label' => 'Battery options', 'message' => 'Which batteries fit?' }, { 'label' => ' ' }]
    )

    expect(service.perform(kind: 'check_in', message_id: reply.id)).to include(
      text: 'Want help choosing a battery?', suggestions: [{ title: 'Battery options', value: 'Which batteries fit?' }]
    )
    expect(Captain::Conversation::CheckInService).to have_received(:new).with(conversation: conversation, assistant: assistant, widget: true)
  end

  it 'grants the check-in without text when the assistant could not write one' do
    reply = exchange('answer_complete')
    allow(check_in_writer).to receive(:generated).and_raise(RubyLLM::ConfigurationError)

    grant = service.perform(kind: 'check_in', message_id: reply.id)

    expect(grant).to include(kind: 'check_in')
    expect(grant).not_to include(:text)
  end

  # Each claim happens 40 seconds after its reply, well past the cooldowns, so only the caps can refuse it.
  def claim_later(kind, reply, for_conversation = conversation)
    travel_to(reply.created_at + 40.seconds) { service(for_conversation).perform(kind: kind, message_id: reply.id) }
  end

  it 'never grants a second check-in in the conversation, however often the visitor answers' do
    expect(claim_later('check_in', exchange('answer_complete', at: 30.minutes.ago))).to be_present

    [20, 10].each do |minutes|
      service.perform(kind: 'activity')
      expect(claim_later('check_in', exchange('answer_complete', at: minutes.minutes.ago))).to be_nil
    end
  end

  it 'grants no check-in in another conversation during the same visit' do
    claim_later('check_in', exchange('answer_complete', at: 20.minutes.ago))
    other = create(:conversation, account: account, inbox: inbox, contact: conversation.contact, contact_inbox: contact_inbox, status: :pending)

    expect(claim_later('check_in', exchange('answer_complete', at: 10.minutes.ago, in_conversation: other), other)).to be_nil
  end

  it 'claims each reply once, so a reload or second tab gets nothing' do
    reply = exchange('answer_complete')
    service.perform(kind: 'check_in', message_id: reply.id)

    expect(service.perform(kind: 'check_in', message_id: reply.id)).to be_nil
    expect(WidgetAttentionEvent.where(conversation: conversation).count).to eq(1)
  end

  it 'waits for the configured quiet time' do
    reply = exchange('answer_complete', at: 10.seconds.ago)

    expect(service.perform(kind: 'check_in', message_id: reply.id)).to be_nil
  end

  it 'grants nothing for a reply that is not the latest message' do
    reply = exchange('answer_complete')
    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming, sender: conversation.contact)

    expect(service.perform(kind: 'check_in', message_id: reply.id)).to be_nil
  end

  it 'grants nothing when the reply already offered a next step or its intent is unknown' do
    expect(service.perform(kind: 'check_in', message_id: exchange('offered').id)).to be_nil
    expect(service.perform(kind: 'question', message_id: exchange('none').id)).to be_nil
  end

  it 'gives at most two question cues per visit, three minutes apart' do
    first = exchange('awaiting_answer', at: 10.minutes.ago)
    travel_to(first.created_at + 30.seconds) { expect(service.perform(kind: 'question', message_id: first.id)).to be_present }

    second = exchange('awaiting_answer', at: 8.minutes.ago)
    travel_to(second.created_at + 30.seconds) { expect(service.perform(kind: 'question', message_id: second.id)).to be_nil }

    third = exchange('awaiting_answer', at: 5.minutes.ago)
    travel_to(third.created_at + 30.seconds) { expect(service.perform(kind: 'question', message_id: third.id)).to be_present }

    fourth = exchange('awaiting_answer')
    expect(service.perform(kind: 'question', message_id: fourth.id)).to be_nil
  end

  it 'stops automatic re-engagement after the visitor dismisses it' do
    service.perform(kind: 'snooze')

    expect(service.perform(kind: 'check_in', message_id: exchange('answer_complete').id)).to be_nil
  end

  it 'keeps the conversation cap after a new visit starts' do
    claim_later('check_in', exchange('answer_complete', at: 2.hours.ago))
    service.perform(kind: 'activity')

    expect(WidgetAttentionSession.find_by(contact_inbox: contact_inbox)).not_to be_checked_in
    expect(service.perform(kind: 'check_in', message_id: exchange('answer_complete').id)).to be_nil
  end

  it 'grants nothing while a human owns the conversation' do
    reply = exchange('answer_complete')
    conversation.update!(status: :open)

    expect(service.perform(kind: 'check_in', message_id: reply.id)).to be_nil
  end

  it 'grants one sound per reply and keeps sounds 30 seconds apart' do
    reply = exchange('answer_complete', at: 20.seconds.ago)
    expect(service.perform(kind: 'sound', message_id: reply.id)).to include(kind: 'sound')
    expect(service.perform(kind: 'sound', message_id: reply.id)).to be_nil

    expect(service.perform(kind: 'sound', message_id: exchange('answer_complete', at: Time.current).id)).to be_nil
  end

  it 'records what the visitor did with a claim' do
    grant = service.perform(kind: 'check_in', message_id: exchange('answer_complete').id)

    service.perform(kind: 'presented', event_id: grant[:event_id])
    service.perform(kind: 'dismissed', event_id: grant[:event_id])

    expect(WidgetAttentionEvent.find(grant[:event_id]).status).to eq('dismissed')
  end
end

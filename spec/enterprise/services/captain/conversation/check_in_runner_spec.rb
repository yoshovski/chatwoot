require 'rails_helper'

RSpec.describe Captain::Conversation::CheckInRunner do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:config) { { 'auto_resolve_mode' => 'evaluated', 'auto_resolve_after' => 60 } }
  let(:assistant) { create(:captain_assistant, account: account, config: config) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, status: :pending) }
  let(:runner) { described_class.new(inbox: inbox.reload, assistant: assistant) }

  before do
    account.enable_features!('captain_integration_v2')
    create(:captain_inbox, inbox: inbox, captain_assistant: assistant)
    allow(Captain::Conversation::CheckInService).to receive(:new).and_return(
      instance_double(Captain::Conversation::CheckInService, perform: 'Did that answer your question about the Pro plan?')
    )
  end

  def message(type, at:, sender: nil, **attrs)
    sender ||= type == :incoming ? conversation.contact : assistant
    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: type,
                     sender: sender, created_at: at, **attrs)
  end

  def quiet_exchange(minutes_ago: 40)
    message(:incoming, at: (minutes_ago + 1).minutes.ago, content: 'What does the Pro plan include?')
    message(:outgoing, at: minutes_ago.minutes.ago, content: 'The Pro plan includes unlimited projects.')
  end

  def check_ins = conversation.messages.where("additional_attributes->>'captain_initiated' = 'check_in'")

  describe '.proactive_check_in_delay' do
    it 'returns 90 seconds for widget conversation when awaiting customer answer' do
      message(:incoming, at: 2.minutes.ago, content: 'Can I charge with this?')
      message(:outgoing, at: 100.seconds.ago, content: 'Which charger model do you use?')

      expect(described_class.proactive_check_in_delay(assistant, conversation)).to eq(90.seconds)
    end

    it 'returns 150 seconds for widget conversation when answer was complete' do
      message(:incoming, at: 3.minutes.ago, content: 'What is the warranty?')
      message(:outgoing, at: 160.seconds.ago, content: 'The warranty is 12 months.')

      expect(described_class.proactive_check_in_delay(assistant, conversation)).to eq(150.seconds)
    end

    it 'falls back to check_in_after for non-widget inboxes' do
      email_inbox = create(:inbox, :with_email, account: account)
      email_conversation = create(:conversation, account: account, inbox: email_inbox, status: :pending)

      expect(described_class.proactive_check_in_delay(assistant, email_conversation)).to eq(30.minutes)
    end
  end

  describe '#check_in with proactive: true' do
    it 'delivers proactive check-in once delay elapsed' do
      message(:incoming, at: 3.minutes.ago, content: 'What is the warranty?')
      message(:outgoing, at: 160.seconds.ago, content: 'The warranty is 12 months.')

      expect(runner.check_in(conversation, proactive: true)).to be(true)
      expect(check_ins.count).to eq(1)
    end

    it 'does not deliver if the conversation is not yet quiet enough' do
      message(:incoming, at: 2.minutes.ago, content: 'What is the warranty?')
      message(:outgoing, at: 30.seconds.ago, content: 'The warranty is 12 months.')

      expect(runner.check_in(conversation, proactive: true)).to be(false)
      expect(check_ins).to be_empty
    end
  end

  describe '.check_in_after' do
    it 'waits half of auto-resolve, rounded down to 5 minutes and kept between 5 and 30 minutes' do
      { 60 => 30, 15 => 5, 5 => 5, 25 => 10, 45 => 20, 240 => 30 }.each do |after, expected|
        assistant.update!(config: config.merge('auto_resolve_after' => after))
        expect(described_class.check_in_after(assistant)).to eq(expected.minutes), "auto_resolve_after #{after}"
      end
    end

    it 'waits 15 minutes when auto-resolve is disabled' do
      assistant.update!(config: config.merge('auto_resolve_mode' => 'disabled'))

      expect(described_class.check_in_after(assistant)).to eq(15.minutes)
    end
  end

  it 'sends one AI check-in as the agent once the quiet period passed' do
    quiet_exchange

    expect(Captain::ConversationEvents).to receive(:checked_in)
      .with(conversation: conversation, assistant: assistant, kind: 'check_in', at: kind_of(Time))
    expect(runner.perform).to eq([conversation.id])

    check_in = check_ins.sole
    expect(check_in).to have_attributes(content: 'Did that answer your question about the Pro plan?', sender: assistant,
                                        message_type: 'outgoing', private: false)
    expect(conversation.reload.last_activity_at).to be_within(5.seconds).of(Time.current)
  end

  it 'waits until the check-in time' do
    quiet_exchange(minutes_ago: 20)

    expect(runner.perform).to be_empty
    expect(check_ins).to be_empty
  end

  it 'sends only one check-in per quiet period' do
    quiet_exchange
    runner.perform
    conversation.update_columns(last_activity_at: 40.minutes.ago) # rubocop:disable Rails/SkipsModelValidations

    expect(described_class.new(inbox: inbox, assistant: assistant).perform).to be_empty
    expect(check_ins.count).to eq(1)
  end

  it 'starts a new quiet period when the visitor writes again' do
    quiet_exchange(minutes_ago: 120)
    message(:outgoing, at: 100.minutes.ago, content: 'Anything else?',
                       additional_attributes: { 'captain_initiated' => 'check_in' })
    message(:incoming, at: 41.minutes.ago, content: 'And the Team plan?')
    message(:outgoing, at: 40.minutes.ago, content: 'The Team plan adds shared workspaces.')

    expect(runner.perform).to eq([conversation.id])
    expect(check_ins.count).to eq(2)
  end

  it 'works when auto-resolve is disabled' do
    assistant.update!(config: config.merge('auto_resolve_mode' => 'disabled'))
    quiet_exchange(minutes_ago: 20)

    expect(runner.perform).to eq([conversation.id])
  end

  it 'sends nothing when the visitor wrote last' do
    message(:outgoing, at: 41.minutes.ago, content: 'How can I help?')
    message(:incoming, at: 40.minutes.ago, content: 'Do you ship to Canada?')

    expect(runner.perform).to be_empty
  end

  it 'sends nothing when a colleague wrote last' do
    message(:incoming, at: 41.minutes.ago, content: 'Do you ship to Canada?')
    message(:outgoing, at: 40.minutes.ago, sender: create(:user, account: account), content: 'Yes, we do.')

    expect(runner.perform).to be_empty
  end

  it 'sends nothing while a contact form waits for the visitor' do
    message(:incoming, at: 41.minutes.ago, content: 'I want a demo')
    form = Captain::Leads::FollowupFormService.new(assistant, conversation).payload
    message(:outgoing, at: 40.minutes.ago, **form.slice(:content, :content_type, :content_attributes))

    expect(runner.perform).to be_empty
  end

  it 'sends nothing when the visitor never wrote' do
    message(:outgoing, at: 40.minutes.ago, content: 'Hi! Looking for a plan for your team?')

    expect(runner.perform).to be_empty
  end

  it 'keeps going when one check-in fails' do
    quiet_exchange
    allow(Captain::Conversation::CheckInService).to receive(:new).and_raise(ActiveRecord::StatementInvalid)

    expect(runner.perform).to be_empty
  end

  it 'sends nothing when the conversation was handed off' do
    quiet_exchange
    conversation.update!(status: :open)

    expect(runner.perform).to be_empty
  end

  it 'sends nothing when the agent may not reply' do
    quiet_exchange
    allow(Captain::Conversation::OwnershipService).to receive(:new)
      .and_return(instance_double(Captain::Conversation::OwnershipService, may_reply?: false, waiting?: false))

    expect(runner.perform).to be_empty
  end

  it 'sends nothing for conversations quiet for more than a day' do
    quiet_exchange(minutes_ago: 25 * 60)

    expect(runner.perform).to be_empty
  end

  it 'sends nothing without Captain V2' do
    quiet_exchange
    account.disable_features!('captain_integration_v2')

    expect(runner.perform).to be_empty
  end

  it 'sends one check-in when two runs overlap' do
    quiet_exchange
    other_run = described_class.new(inbox: inbox, assistant: assistant)
    service = instance_double(Captain::Conversation::CheckInService)
    calls = 0
    allow(service).to receive(:perform) do
      calls += 1
      # The other run posts its check-in while this run waits for the model.
      other_run.perform if calls == 1
      'Anything else?'
    end
    allow(Captain::Conversation::CheckInService).to receive(:new).and_return(service)

    runner.perform
    expect(check_ins.count).to eq(1)
  end

  context 'with a business prospect' do
    let(:config) do
      { 'auto_resolve_mode' => 'evaluated', 'auto_resolve_after' => 60, 'leads_enabled' => true,
        'lead_types' => [{ 'name' => 'Demo', 'rule' => 'Wants to see the product' }] }
    end
    let(:offer_service) { instance_double(Captain::Conversation::LeadOfferService, proposal: proposal) }
    let(:proposal) { { 'offer' => 'Our team can email you a walkthrough.', 'lead_type' => 'Demo', 'summary' => 'Agency evaluating.' } }

    before do
      message(:incoming, at: 42.minutes.ago, content: 'Could Acme work for our agency?')
      message(:outgoing, at: 41.minutes.ago, content: 'How many clients do you manage?',
                         additional_attributes: { 'business_lead_question' => true })
      message(:incoming, at: 41.minutes.ago, content: 'About 40')
      message(:outgoing, at: 40.minutes.ago, content: 'Acme handles 40 client workspaces on the Agency plan.')
      allow(Captain::Conversation::LeadOfferService).to receive(:new).and_return(offer_service)
    end

    def lead_offers = conversation.messages.where("additional_attributes->>'captain_initiated' = 'lead_offer'")

    it 'sends a lead offer instead of a plain check-in' do
      allow(offer_service).to receive(:deliver!) do
        [message(:outgoing, at: Time.current, content: proposal['offer'], additional_attributes: { 'captain_initiated' => 'lead_offer' })]
      end
      expect(Captain::ConversationEvents).to receive(:checked_in).with(hash_including(kind: 'lead_offer'))

      expect(runner.perform).to eq([conversation.id])
      expect(lead_offers.count).to eq(1)
      expect(check_ins).to be_empty
    end

    it 'never sends a second lead offer' do
      message(:outgoing, at: 50.minutes.ago, content: 'Our team can email you.', additional_attributes: { 'captain_initiated' => 'lead_offer' })
      message(:incoming, at: 41.minutes.ago, content: 'Maybe later')
      message(:outgoing, at: 40.minutes.ago, content: 'Sure, take your time.')
      allow(offer_service).to receive(:deliver!)

      runner.perform

      expect(offer_service).not_to have_received(:deliver!)
      expect(check_ins.count).to eq(1)
    end

    it 'sends a plain check-in that marks the offer skipped when follow-up is not appropriate' do
      allow(offer_service).to receive(:deliver!).and_return(nil)

      runner.perform

      expect(check_ins.sole.additional_attributes).to include('lead_offer_skipped' => true)
      expect(Captain::Conversation::CheckInState.new(conversation: conversation, assistant: assistant).lead_guard?).to be(false)
    end

    it 'falls back to a plain check-in when the offer cannot be written' do
      allow(offer_service).to receive(:proposal).and_return(nil)

      runner.perform

      expect(check_ins.sole.additional_attributes).to include('lead_offer_skipped' => true)
    end

    it 'keeps auto-resolve waiting for the offer' do
      expect(described_class.awaiting_lead_offer?(conversation, assistant)).to be(true)

      message(:outgoing, at: Time.current, content: proposal['offer'], additional_attributes: { 'captain_initiated' => 'lead_offer' })
      expect(described_class.awaiting_lead_offer?(conversation, assistant)).to be(false)
    end

    it 'does not wait when the visitor wrote last, since no offer can follow' do
      message(:incoming, at: 39.minutes.ago, content: 'Hello?')

      expect(described_class.awaiting_lead_offer?(conversation, assistant)).to be(false)
    end
  end
end

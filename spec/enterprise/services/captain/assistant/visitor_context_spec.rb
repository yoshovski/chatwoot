require 'rails_helper'

RSpec.describe Captain::Assistant::VisitorContext do
  let(:activity) do
    { 'timezone' => 'Europe/Madrid', 'visit_count' => 3, 'first_seen_at' => '2026-10-01T09:00:00.000000Z',
      'arrival' => { 'referrer_host' => 'www.google.com', 'utm_campaign' => 'spring-sale', 'landed_at' => '2026-11-04T10:00:00Z' } }
  end
  let(:state) do
    { website_activity: activity,
      contact: { additional_attributes: { 'city' => 'Valencia', 'country' => 'Spain', 'created_at_ip' => '203.0.113.9' } },
      visitor_history: { earlier_conversations: 1, last_conversation_status: 'resolved' } }
  end

  it 'adds location, local time, returning visitor and arrival, without IP addresses' do
    travel_to(Time.utc(2026, 11, 4, 17, 30)) do
      context = described_class.from_state(state)

      expect(context).to include(location: 'Valencia, Spain', local_time: 'Wednesday 18:30 (CET)',
                                 arrival: { 'referrer_host' => 'www.google.com', 'utm_campaign' => 'spring-sale' })
      expect(context[:returning]).to eq(visit: '3rd', earlier_conversations: 1, last_conversation_status: 'resolved', first_seen_on: '2026-10-01')
      expect(context.to_s).not_to include('203.0.113.9')
    end
  end

  it 'omits the local time without a known time zone and the returning line for a first visit' do
    context = described_class.from_state(state.merge(website_activity: { 'visit_count' => 1 }, visitor_history: { earlier_conversations: 0 }))

    expect(context.keys).to eq([:location])
  end

  it 'counts a visitor with an earlier conversation as returning on their first tracked visit' do
    context = described_class.from_state(website_activity: {}, visitor_history: { earlier_conversations: 2, last_conversation_status: 'open' })

    expect(context[:returning]).to eq(earlier_conversations: 2, last_conversation_status: 'open')
  end

  describe 'with the runner state' do
    let(:account) { create(:account) }
    let(:inbox) { create(:inbox, account: account) }
    let(:contact) { create(:contact, account: account, additional_attributes: { 'city' => 'Lyon', 'country' => 'France' }) }
    let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
    let(:assistant) { create(:captain_assistant, account: account, config: { 'feature_contact_attributes' => false }) }

    it 'uses the location without the contact attributes setting and counts only earlier conversations in this inbox' do
      create(:conversation, account: account, inbox: inbox, contact: contact, status: :resolved)
      create(:conversation, account: account, inbox: create(:inbox, account: account), contact: contact)
      state = Captain::Assistant::AgentRunnerService.new(assistant: assistant, conversation: conversation).send(:build_state)

      context = described_class.from_state(state)

      expect(context[:location]).to eq('Lyon, France')
      expect(context[:returning]).to include(earlier_conversations: 1, last_conversation_status: 'resolved')
    end
  end
end

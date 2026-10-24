require 'rails_helper'

RSpec.describe Crm::Hubspot::Mappers::TranscriptNoteMapper do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, name: 'Website <Chat>') }
  let(:contact) { create(:contact, account: account, name: 'Jane Doe') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:agent) { create(:user, account: account, name: 'Sam Agent') }
  let(:assistant) { create(:captain_assistant, account: account) }

  before do
    allow(GlobalConfig).to receive(:get).and_return({})
    allow(GlobalConfig).to receive(:get).with('BRAND_NAME').and_return({ 'BRAND_NAME' => 'TestBrand' })
  end

  it 'lists the messages in order with their sender, escaped, and leaves out private notes and activity' do
    travel_to(Time.zone.parse('2026-01-02 10:00:00 UTC')) do
      create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming, sender: contact,
                       content: "Hi <script>alert(1)</script>\nsecond line")
    end
    travel_to(Time.zone.parse('2026-01-02 10:01:00 UTC')) do
      create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing, sender: assistant,
                       content: 'Happy to help')
      create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing, sender: agent,
                       content: 'Taking over', private: true)
      create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :activity, content: 'Assigned')
    end
    travel_to(Time.zone.parse('2026-01-02 10:02:00 UTC')) do
      create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing, sender: agent,
                       content: 'Anything else?')
    end

    body = described_class.new(conversation).body

    expect(body).to start_with('<p><strong>Conversation transcript from TestBrand</strong><br>Inbox: Website &lt;Chat&gt;<br>')
    expect(body).to include("View conversation ##{conversation.display_id}</a>")
    expect(body).to include('<p><strong>Contact</strong> · 2026-01-02 10:00 UTC<br>Hi &lt;script&gt;alert(1)&lt;/script&gt;<br>second line</p>')
    expect(body.index('<strong>AI agent</strong> · 2026-01-02 10:01 UTC<br>Happy to help')).to be < body.index('<strong>Sam Agent</strong>')
    expect(body).not_to include('Taking over')
    expect(body).not_to include('Assigned')
    expect(body).not_to include('shortened')
  end

  it 'keeps the newest messages under the HubSpot limit and notes the cut at the top' do
    stub_const("#{described_class}::NOTE_MAX_SIZE", 1000)
    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming, content: 'oldest message')
    3.times { create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming, content: 'x' * 200) }
    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming, content: 'newest message')

    body = described_class.new(conversation).body

    expect(body.length).to be <= 1000
    expect(body).to start_with('<p><em>Transcript shortened to fit HubSpot')
    expect(body).to include('newest message')
    expect(body).not_to include('oldest message')
  end
end

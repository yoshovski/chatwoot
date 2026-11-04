require 'rails_helper'

RSpec.describe Captain::ScheduledActions::FollowUpMessageHandler do
  let(:account) { create(:account) }
  let(:templates) { { 'nudge' => { 'subject' => 'Still deciding?', 'body' => 'Hi {{ contact.first_name }}, any questions?' } } }
  let(:assistant) { create(:captain_assistant, account: account, config: { 'email_templates' => templates }) }
  let(:contact) { create(:contact, account: account, name: 'Jamie', email: 'jamie@harbor-bikes.test') }
  let(:conversation) { create(:conversation, account: account, contact: contact) }

  it 'posts the template as an AI follow-up message' do
    action = create(:captain_scheduled_action, conversation: conversation, assistant: assistant, payload: { 'template' => 'nudge' })

    described_class.new(action).perform

    expect(conversation.messages.last).to have_attributes(
      content: 'Hi Jamie, any questions?', message_type: 'outgoing', sender: assistant,
      additional_attributes: include('captain_initiated' => 'follow_up')
    )
  end

  it 'writes the follow-up from the instructions through the check-in writer' do
    action = create(:captain_scheduled_action, conversation: conversation, assistant: assistant, payload: { 'instructions' => 'Ask about the demo' })
    writer = instance_double(Captain::Conversation::CheckInService, perform: 'Did you get a chance to look at the demo?')
    allow(Captain::Conversation::CheckInService).to receive(:new)
      .with(conversation: conversation, assistant: assistant, brief: 'Ask about the demo').and_return(writer)

    described_class.new(action).perform

    expect(conversation.messages.last.content).to eq('Did you get a chance to look at the demo?')
  end
end

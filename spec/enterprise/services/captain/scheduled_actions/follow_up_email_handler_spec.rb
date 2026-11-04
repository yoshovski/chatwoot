require 'rails_helper'

RSpec.describe Captain::ScheduledActions::FollowUpEmailHandler do
  let(:account) { create(:account) }
  let(:templates) { { 'nudge' => { 'subject' => 'Still deciding?', 'body' => 'Hi {{ contact.first_name }}, any questions?' } } }
  let(:assistant) { create(:captain_assistant, account: account, config: { 'email_templates' => templates }) }
  let(:contact) { create(:contact, account: account, name: 'Jamie', email: 'jamie@harbor-bikes.test') }
  let(:conversation) { create(:conversation, account: account, contact: contact) }

  it 'emails the template and raises when it cannot' do
    action = create(:captain_scheduled_action, conversation: conversation, assistant: assistant, kind: 'follow_up_email',
                                               payload: { 'template' => 'nudge' })

    expect { described_class.new(action).perform }
      .to have_enqueued_mail(Captain::ActionsMailer, :visitor_email).with(conversation, 'Still deciding?', 'Hi Jamie, any questions?')

    contact.update!(email: nil)
    expect { described_class.new(action).perform }.to raise_error(/no_email/)
  end
end

require 'rails_helper'

RSpec.describe Captain::Tools::EmailVisitorTool do
  let(:account) { create(:account) }
  let(:templates) do
    { 'pricing' => { 'name' => 'Pricing sheet', 'subject' => 'Plans for {{ contact.first_name }}', 'body' => 'Hi! — {{ agent.name }}' } }
  end
  let(:assistant) { create(:captain_assistant, account: account, name: 'Ada', config: { 'email_templates' => templates }) }
  let(:contact) { create(:contact, account: account, name: 'jamie rivera', email: 'jamie@harbor-bikes.test') }
  let(:conversation) { create(:conversation, account: account, contact: contact) }
  let(:tool_context) { Struct.new(:state).new({ conversation: { id: conversation.id } }) }
  let(:tool) { described_class.new(assistant, fixed_params: { template: 'pricing' }) }

  it 'sends the rendered template once per conversation' do
    expect { tool.perform(tool_context) }.to have_enqueued_mail(Captain::ActionsMailer, :visitor_email)
      .with(conversation, 'Plans for Jamie', 'Hi! — Ada', nil)
    expect(tool.perform(tool_context)).to include('already sent')
  end

  it 'asks for an email first' do
    contact.update!(email: nil)

    expect(tool.perform(tool_context)).to include('No email address')
  end

  it 'stops at the account email limit' do
    allow(ChatwootApp).to receive(:chatwoot_cloud?).and_return(true)
    account.update!(limits: { 'emails' => 0 })

    expect { expect(tool.perform(tool_context)).to include("couldn't be sent today") }
      .not_to have_enqueued_mail(Captain::ActionsMailer, :visitor_email)
  end

  it 'refuses on an email inbox' do
    email_conversation = create(:conversation, account: account, contact: contact, inbox: create(:channel_email, account: account).inbox)
    tool_context.state[:conversation][:id] = email_conversation.id

    expect(tool.perform(tool_context)).to include('already by email')
  end

  it 'reports an unknown template' do
    expect(described_class.fixed_param_errors(assistant, 'template' => 'missing')).to eq(['no email template missing'])
  end
end

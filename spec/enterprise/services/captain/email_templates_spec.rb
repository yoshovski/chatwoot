require 'rails_helper'

RSpec.describe Captain::EmailTemplates do
  let(:account) { create(:account) }

  it 'validates templates on the assistant' do
    assistant = build(:captain_assistant, account: account, config: {
                        'email_templates' => { 'Bad Key' => { 'subject' => 'x', 'body' => 'y' }, 'demo' => { 'subject' => '', 'body' => '{% if %}' } }
                      })

    expect(assistant).not_to be_valid
    expect(assistant.errors[:email_templates]).to include('Bad Key: key may only use a-z, 0-9 and _', 'demo: subject is required')
    expect(assistant.errors[:email_templates].join).to include('demo: Liquid syntax error')
  end

  it 'caps the number of templates' do
    templates = 11.times.to_h { |index| ["t#{index}", { 'subject' => 's', 'body' => 'b' }] }

    expect(described_class.errors(templates)).to eq(['can have at most 10 templates'])
  end

  it 'renders contact, conversation, agent and extra locals' do
    assistant = create(:captain_assistant, account: account, name: 'Ada', config: {
                         'email_templates' => { 'demo' => { 'subject' => 'Demo #{{ conversation.display_id }}',
                                                            'body' => '{{ contact.first_name }} / {{ agent.name }} / {{ summary }}' } }
                       })
    conversation = create(:conversation, account: account, contact: create(:contact, account: account, name: 'jamie rivera'))

    expect(described_class.new(assistant).render('demo', conversation, summary: 'wants SSO')).to eq(
      subject: "Demo ##{conversation.display_id}", body: 'Jamie / Ada / wants SSO', html: nil
    )
  end

  it 'renders an HTML template with escaped values, no scripts and a plain-text copy' do
    assistant = create(:captain_assistant, account: account, config: {
                         'email_templates' => { 'demo' => { 'subject' => 'Hi', 'format' => 'html',
                                                            'body' => '<p>Hi {{ contact.name }}</p><script>x()</script><p>{{ business.name }}</p>' } }
                       })
    conversation = create(:conversation, account: account, contact: create(:contact, account: account, name: '<b>Jamie</b>'))

    email = described_class.new(assistant).render('demo', conversation)

    expect(email[:html]).to eq("<p>Hi &lt;b&gt;jamie&lt;/b&gt;</p><p>#{CGI.escapeHTML(account.name)}</p>")
    expect(email[:body]).to eq("Hi <b>jamie</b>\n#{account.name}")
  end

  it 'rejects an unknown format' do
    expect(described_class.errors('demo' => { 'subject' => 's', 'body' => 'b', 'format' => 'pdf' })).to eq(['demo: format must be text or html'])
  end
end

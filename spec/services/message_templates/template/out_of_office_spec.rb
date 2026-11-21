require 'rails_helper'

describe MessageTemplates::Template::OutOfOffice do
  context 'when this hook is called' do
    let(:conversation) { create(:conversation) }

    it 'creates the default out-of-office message' do
      conversation.inbox.update!(out_of_office_message: 'Our team is unavailable at the moment.')

      described_class.new(conversation: conversation).perform
      expect(conversation.messages.template.count).to eq(1)
      expect(conversation.messages.template.first.content).to eq(conversation.inbox.out_of_office_message)
    end

    it 'creates the out of office messages with template variable' do
      conversation.inbox.update!(out_of_office_message: 'Hey, {{contact.name}} we are unavailable at the moment.')
      described_class.new(conversation: conversation).perform
      expect(conversation.messages.count).to eq(1)
      expect(conversation.messages.last.content).to eq("Hey, #{conversation.contact.name} we are unavailable at the moment.")
    end

    it 'uses the reply locale for an after-hours notice and renders its variables' do
      conversation.inbox.update!(out_of_office_message_translations: {
                                   'it' => 'Ciao, {{contact.name}}. Il team risponderà domani.'
                                 })

      described_class.new(conversation: conversation, locale: 'it').perform

      expect(conversation.messages.template.last.content).to eq("Ciao, #{conversation.contact.name}. Il team risponderà domani.")
    end

    it 'uses browser language for a notice outside an AI reply' do
      conversation.inbox.update!(out_of_office_message_translations: { 'es' => 'El equipo volverá mañana.' })
      conversation.update!(additional_attributes: { 'browser_language' => 'es-MX' })

      described_class.new(conversation: conversation).perform

      expect(conversation.messages.template.last.content).to eq('El equipo volverá mañana.')
    end

    it 'creates the out of office messages with more than one variable strings' do
      conversation.inbox.update!(out_of_office_message:
        'Hey, {{contact.name}} we are unavailable at the moment. - from {{account.name}}')
      described_class.new(conversation: conversation).perform
      expect(conversation.messages.count).to eq(1)
      expect(conversation.messages.last.content).to eq(
        "Hey, #{conversation.contact.name} we are unavailable at the moment. - from #{conversation.account.name}"
      )
    end
  end
end

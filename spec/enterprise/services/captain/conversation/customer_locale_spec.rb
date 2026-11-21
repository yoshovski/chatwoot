require 'rails_helper'

RSpec.describe Captain::Conversation::CustomerLocale, type: :service do
  let(:conversation) { create(:conversation, additional_attributes: { browser_language: 'es-MX' }) }

  it 'uses confidently detected Italian ahead of the browser language' do
    expect(described_class.resolve(conversation: conversation, customer_message: 'Potete aiutarmi con la spedizione del mio ordine?')).to eq('it')
  end

  it 'normalizes a regional browser language when a short greeting is ambiguous' do
    expect(described_class.resolve(conversation: conversation, customer_message: 'Ciao')).to eq('es')
  end

  it 'recognizes an opening greeting for an assistant with reply languages configured' do
    assistant = build(:captain_assistant, config: { default_reply_locale: 'it' })
    expect(described_class.resolve(conversation: conversation, assistant: assistant, customer_message: 'Ciao!')).to eq('it')
    described_class.record(conversation.reload, 1, 'en')
    expect(described_class.resolve(conversation: conversation, assistant: assistant, customer_message: 'ciao')).to eq('en')
  end

  it 'keeps the language of an earlier customer turn for a short reply and ignores later messages' do
    create(:message, conversation: conversation, message_type: :incoming, content: 'Vorrei richiedere una dimostrazione per la mia azienda.')
    replying_to = create(:message, conversation: conversation, message_type: :incoming, content: 'Sì')
    create(:message, conversation: conversation, message_type: :incoming, content: 'I would like to speak with your sales team.')

    expect(described_class.resolve(conversation: conversation, customer_message: replying_to)).to eq('it')
  end

  it 'uses the account locale when no customer or browser language is available' do
    assistant = build(:captain_assistant, account: build(:account, locale: 'es'))

    expect(described_class.resolve(assistant: assistant)).to eq('es')
  end

  it 'uses a visitor’s explicit request ahead of the language they wrote in' do
    assistant = build(:captain_assistant, config: { default_reply_locale: 'en', allowed_reply_locales: %w[en it es] })

    expect(described_class.resolve(assistant: assistant, customer_message: 'Please reply in Italian. I have a question about my order.')).to eq('it')
    expect(described_class.resolve(assistant: assistant, customer_message: 'Por favor responde en español.')).to eq('es')
    expect(described_class.resolve(assistant: assistant, customer_message: 'Please reply in French.')).to eq('en')
  end

  it 'uses location as a fallback when the message and browser supply no language' do
    contact = create(:contact, additional_attributes: { 'country_code' => 'IT' })
    visitor = build(:conversation, contact: contact, additional_attributes: {})

    expect(described_class.resolve(conversation: visitor, customer_message: '1234')).to eq('it')
  end

  it 'uses a supported regional Portuguese variant and handles explicit requests beyond the first four languages' do
    assistant = build(:captain_assistant, config: { default_reply_locale: 'en', allowed_reply_locales: %w[en de pt_BR] })

    expect(described_class.resolve(assistant: assistant, customer_message: 'Please reply in German.')).to eq('de')
    expect(described_class.resolve(assistant: assistant, customer_message: 'Please reply in Brazilian Portuguese.')).to eq('pt_BR')
    expect(described_class.resolve(assistant: assistant, customer_message: 'Pode me ajudar com o rastreamento do meu pedido?')).to eq('pt_BR')
  end

  it 'uses the browser script for Chinese before a location fallback' do
    conversation.additional_attributes['browser_language'] = 'zh-Hant-TW'

    expect(described_class.resolve(conversation: conversation, customer_message: '123')).to eq('zh_TW')
  end

  it 'keeps a late response from overwriting the language of a more recent turn' do
    conversation.reload
    described_class.record(conversation, 20, 'it')
    described_class.record(conversation, 19, 'en')

    expect(described_class.resolve(conversation: conversation.reload, customer_message: 'Sì')).to eq('it')
  end

  it 'falls back to English for missing or blank localized strings and preserves interpolation' do
    localized = I18n::Backend::Simple.new
    localized.store_translations(:en, customer_locale_test: 'Thanks, %<name>s.')
    localized.store_translations(:es, customer_locale_test: '')
    allow(I18n.config).to receive(:backend).and_return(localized)

    expect(described_class.translate('customer_locale_test', locale: 'it', name: 'Ada')).to eq('Thanks, Ada.')
    expect(described_class.translate('customer_locale_test', locale: 'es', name: 'Ada')).to eq('Thanks, Ada.')
  end
end

require 'rails_helper'

RSpec.describe Captain::TranslateAssistantMessagesJob do
  let(:assistant) do
    create(:captain_assistant, config: {
             'default_reply_locale' => 'it',
             'auto_translate_messages' => true,
             'handoff_form_message' => 'Please leave your contact details.',
             'localized_messages' => { 'handoff_form_message' => { 'it' => 'Lascia i tuoi recapiti.' } }
           })
  end

  it 'prepares missing built-in form copy while keeping the manual title' do
    allow(Captain::LocalizedMessages).to receive(:catalog_text).and_call_original
    allow(Captain::LocalizedMessages).to receive(:catalog_text).with('captain.contact_form.submit', 'it').and_return(nil)
    allow(Captain::LocalizedMessages).to receive(:catalog_text).with('captain.contact_form.fields.email.label', 'it').and_return(nil)
    translation = instance_double(Captain::Llm::MessageTranslationService, perform: {
                                    'captain.contact_form.submit' => 'Invia',
                                    'captain.contact_form.fields.email.label' => 'Indirizzo email'
                                  })
    allow(Captain::Llm::MessageTranslationService).to receive(:new).with(
      account: assistant.account, locale: 'it', source_messages: hash_including('captain.contact_form.submit' => 'Submit')
    ).and_return(translation)

    described_class.perform_now(assistant.id)

    payload = Captain::Conversation::ContactCaptureService.form_payload(['email'], assistant: assistant.reload, locale: 'it')
    expect(payload[:content]).to eq('Lascia i tuoi recapiti.')
    expect(payload[:content_attributes]).to include('button_label' => 'Invia', 'contact_form_locale' => 'it')
    expect(payload[:content_attributes]['items'].first).to include('name' => 'email', 'label' => 'Indirizzo email')
  end

  it 'does not request generation when the catalog and manual wording cover all inputs' do
    expect(Captain::Llm::MessageTranslationService).not_to receive(:new)

    described_class.perform_now(assistant.id)
  end

  it 'discards a translation if the source changes while it is being prepared' do
    config = assistant.config.except('localized_messages')
    assistant.update!(config: config)
    translation = instance_double(Captain::Llm::MessageTranslationService)
    allow(Captain::Llm::MessageTranslationService).to receive(:new).and_return(translation)
    allow(translation).to receive(:perform) do
      assistant.update!(config: config.merge('handoff_form_message' => 'Tell us where to contact you.'))
      { 'handoff_form_message' => 'Lascia i tuoi recapiti per essere contattato.' }
    end

    described_class.perform_now(assistant.id)

    messages = Captain::LocalizedMessages.new(assistant.reload.config)
    expect(messages.generated_text('handoff_form_message', 'it')).to be_nil
    expect(messages.text('handoff_form_message', 'it')).to eq('Tell us where to contact you.')
  end
end

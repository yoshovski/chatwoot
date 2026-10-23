require 'rails_helper'

RSpec.describe Crm::Hubspot::ProcessorService do
  let(:account) { create(:account) }
  let(:hook) { create(:integrations_hook, :hubspot, account: account) }
  let(:service) { described_class.new(hook) }
  let(:upsert_url) { 'https://api.hubapi.com/crm/v3/objects/contacts/batch/upsert' }
  let(:lead_mapping) do
    { 'lead_type' => 'chatoctave_lead_type', 'lead_summary' => 'chatoctave_lead_summary',
      'lead_company' => 'company', 'lead_source' => 'chatoctave_lead_source' }
  end
  let(:contact) { create(:contact, account: account, name: 'Jane Doe', email: 'jane@example.com', phone_number: '+15550100') }

  def stub_upsert(properties)
    stub_request(:post, upsert_url)
      .with(body: { inputs: [{ id: 'jane@example.com', idProperty: 'email', properties: properties }] }.to_json)
      .to_return(status: 200, body: { results: [{ id: '901' }] }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  describe '#handle_contact' do
    it 'upserts the base properties of any contact with an email and stores the HubSpot id' do
      upsert = stub_upsert('email' => 'jane@example.com', 'firstname' => 'Jane', 'lastname' => 'Doe', 'phone' => '+15550100')

      service.handle_contact(contact)

      expect(upsert).to have_been_requested.once
      expect(contact.reload.additional_attributes['external']).to eq('hubspot_id' => '901')
      expect(contact.additional_attributes['hubspot_sync_status']).to eq('synced')
    end

    it 'does not call HubSpot again when nothing changed' do
      upsert = stub_upsert('email' => 'jane@example.com', 'firstname' => 'Jane', 'lastname' => 'Doe', 'phone' => '+15550100')

      2.times { service.handle_contact(contact.reload) }

      expect(upsert).to have_been_requested.once
    end

    it 'drops blank values so they never overwrite HubSpot' do
      contact.update!(name: 'Jane', phone_number: nil)
      upsert = stub_upsert('email' => 'jane@example.com', 'firstname' => 'Jane')

      service.handle_contact(contact)

      expect(upsert).to have_been_requested
    end

    it 'skips contacts without an email' do
      contact.update!(email: nil)

      expect(service.handle_contact(contact)).to be_nil
      expect(a_request(:post, upsert_url)).not_to have_been_made
    end

    it 'skips contacts when contact sync is off' do
      hook.update!(settings: hook.settings.merge('sync_contacts' => false))

      expect(service.handle_contact(contact)).to be_nil
      expect(a_request(:post, upsert_url)).not_to have_been_made
    end

    context 'with lead fields mapped' do
      let(:assistant) do
        create(:captain_assistant, account: account, config: {
                 'leads_enabled' => true, 'lead_types' => [{ 'name' => 'Partner', 'rule' => 'Wants to partner' }],
                 'lead_fields' => [{ 'key' => 'company', 'label' => 'Company' }]
               })
      end

      before do
        hook.settings['field_mapping'].merge!(lead_mapping)
        hook.save!(validate: false)
      end

      it 'sends lead fields for a captured lead with a valid receipt' do
        Captain::Leads::CaptureService.new(assistant, contact).perform(
          name: 'Jane Doe', email: 'jane@example.com', lead_type: 'Partner', summary: 'Wants a demo', fields: { 'company' => 'Acme' }
        )
        upsert = stub_upsert('email' => 'jane@example.com', 'firstname' => 'Jane', 'lastname' => 'Doe', 'phone' => '+15550100',
                             'chatoctave_lead_type' => 'Partner', 'chatoctave_lead_summary' => 'Wants a demo',
                             'company' => 'Acme', 'chatoctave_lead_source' => 'chatbot')

        service.handle_contact(contact.reload)

        expect(upsert).to have_been_requested
      end

      it 'sends only base properties and the source when lead attributes have no valid receipt' do
        contact.update!(custom_attributes: { 'lead_status' => 'captured', 'lead_type' => 'Partner', 'lead_company' => 'Spoofed' },
                        additional_attributes: { 'lead_assistant_id' => assistant.id, 'lead_capture_receipt' => 'forged' })
        upsert = stub_upsert('email' => 'jane@example.com', 'firstname' => 'Jane', 'lastname' => 'Doe', 'phone' => '+15550100',
                             'chatoctave_lead_source' => 'chatbot')

        service.handle_contact(contact)

        expect(upsert).to have_been_requested
      end
    end
  end

  describe '#handle_conversation_resolved' do
    let(:conversation) { create(:conversation, account: account, contact: contact) }
    let(:resolved_at) { Time.zone.parse('2026-01-02 10:00:00 UTC') }
    let(:notes_url) { 'https://api.hubapi.com/crm/v3/objects/notes' }

    before do
      create(:message, conversation: conversation, account: account, inbox: conversation.inbox, message_type: :incoming,
                       content: 'Do you ship to Canada?')
      stub_upsert('email' => 'jane@example.com', 'firstname' => 'Jane', 'lastname' => 'Doe', 'phone' => '+15550100')
    end

    it 'upserts the contact, posts the transcript note and stores its id by resolve time' do
      note = stub_request(:post, notes_url)
             .with { |request| JSON.parse(request.body).then { |body| note_request?(body) } }
             .to_return(status: 201, body: { id: '555' }.to_json, headers: { 'Content-Type' => 'application/json' })

      service.handle_conversation_resolved(conversation, resolved_at)

      expect(note).to have_been_requested.once
      expect(conversation.reload.additional_attributes['hubspot_note_ids']).to eq('2026-01-02T10:00:00Z' => '555')
    end

    it 'does not post twice for the same resolve, but posts again when resolved later' do
      note = stub_request(:post, notes_url).to_return(status: 201, body: { id: '555' }.to_json,
                                                      headers: { 'Content-Type' => 'application/json' })

      2.times { service.handle_conversation_resolved(conversation.reload, resolved_at) }
      service.handle_conversation_resolved(conversation.reload, resolved_at + 1.day)

      expect(note).to have_been_requested.twice
    end

    it 'skips when transcripts are off or the contact has no email' do
      hook.update!(settings: hook.settings.merge('save_transcripts' => false))
      service.handle_conversation_resolved(conversation, resolved_at)

      hook.update!(settings: hook.settings.merge('save_transcripts' => true))
      contact.update!(email: nil)
      service.handle_conversation_resolved(conversation.reload, resolved_at)

      expect(a_request(:post, notes_url)).not_to have_been_made
    end

    def note_request?(body)
      body['properties']['hs_timestamp'] == '2026-01-02T10:00:00.000Z' &&
        body['properties']['hs_note_body'].include?('Do you ship to Canada?') &&
        body['associations'] == [{ 'to' => { 'id' => '901' },
                                   'types' => [{ 'associationCategory' => 'HUBSPOT_DEFINED', 'associationTypeId' => 202 }] }]
    end
  end
end

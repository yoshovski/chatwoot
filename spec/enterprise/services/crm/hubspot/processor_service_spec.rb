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
end

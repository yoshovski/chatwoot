require 'rails_helper'

RSpec.describe Crm::Hubspot::ContactCardService do
  let(:account) { create(:account) }
  let(:hook) { create(:integrations_hook, :hubspot, account: account) }

  it 'returns found false without calling HubSpot for a contact with no email or HubSpot id' do
    contact = create(:contact, account: account, email: nil)

    expect(described_class.new(hook).perform(contact)).to eq(found: false)
    expect(a_request(:any, /api.hubapi.com/)).not_to have_been_made
  end

  it 'falls back to the email search when the stored HubSpot id was deleted' do
    contact = create(:contact, account: account, email: 'jane@example.com',
                               additional_attributes: { 'external' => { 'hubspot_id' => '404' } })
    stub_request(:get, %r{/crm/v3/objects/contacts/404}).to_return(status: 404)
    search = stub_request(:post, 'https://api.hubapi.com/crm/v3/objects/contacts/search')
             .to_return(status: 200, body: { results: [{ id: '902', properties: { email: 'jane@example.com' } }] }.to_json,
                        headers: { 'Content-Type' => 'application/json' })

    card = described_class.new(hook).perform(contact)

    expect(search).to have_been_requested
    expect(card).to include(found: true, id: '902', name: nil, email: 'jane@example.com', lifecyclestage: nil)
  end
end

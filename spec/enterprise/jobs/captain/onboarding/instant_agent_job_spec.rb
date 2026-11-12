require 'rails_helper'

RSpec.describe Captain::Onboarding::InstantAgentJob do
  let(:assistant) { create(:captain_assistant, name: 'AI agent', description: 'Default') }
  let(:source) { Captain::WebsiteSource.create!(assistant: assistant, url: 'https://www.example.com') }
  let(:service) { instance_double(Captain::Onboarding::InstantAgentService) }
  let(:result) do
    { status: 'ready',
      pages: [{ url: 'https://www.example.com', title: 'Example', content: 'Handmade ceramics shipped across Europe.' },
              { url: 'https://www.example.com/shipping', title: 'Shipping', content: 'Delivery takes three days.' }],
      profile: { name: 'Example Helper', brief: 'You help Example customers.', language: 'en', brand_color: '#1f6feb',
                 logo_url: 'https://www.example.com/logo.png', starter_questions: ['How long does delivery take?'] } }
  end

  before do
    allow(Captain::Onboarding::InstantAgentService).to receive(:new).with(source.url, account_id: source.account_id).and_return(service)
    allow(service).to receive(:perform).and_return(result)
  end

  it 'stores the pages as quick-start documents and names the new agent' do
    described_class.perform_now(source.id, name_agent: true)

    documents = assistant.documents.order(:id)
    expect(documents.map(&:external_link)).to eq(['https://www.example.com', 'https://www.example.com/shipping'])
    expect(documents.first).to have_attributes(status: 'available', content: include('ceramics'))
    expect(documents.first.metadata).to include('quick_start' => true, 'website_source_id' => source.id)
    expect(assistant.reload).to have_attributes(name: 'Example Helper', description: 'You help Example customers.')
    expect(assistant.config['instant_agent']).to include('status' => 'ready', 'language' => 'en', 'brand_color' => '#1f6feb',
                                                         'starter_questions' => ['How long does delivery take?'])
  end

  it 'keeps the name of an agent the owner already had and pages that are already knowledge' do
    create(:captain_document, assistant: assistant, account: assistant.account, external_link: 'https://www.example.com/shipping')

    described_class.perform_now(source.id, name_agent: false)

    expect(assistant.reload.name).to eq('AI agent')
    expect(assistant.documents.where("metadata->>'quick_start' = 'true'").pluck(:external_link)).to eq(['https://www.example.com'])
  end

  it 'marks a site that blocks fetching as blocked without creating documents' do
    allow(service).to receive(:perform).and_return(status: 'blocked', pages: [], profile: {})

    described_class.perform_now(source.id, name_agent: true)

    expect(assistant.documents).to be_empty
    expect(assistant.reload).to have_attributes(name: 'AI agent')
    expect(assistant.config['instant_agent']['status']).to eq('blocked')
  end
end

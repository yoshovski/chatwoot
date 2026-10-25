require 'rails_helper'

RSpec.describe Captain::Knowledge::OfferingEnumerator do
  let(:account) { create(:account) }
  let(:assistant) do
    create(:captain_assistant, account: account, config: { 'knowledge_brief_enabled' => true, 'max_suggested_replies' => 3 })
  end
  let(:doc1) do
    create(:captain_document, assistant: assistant, account: account, status: :available,
                              name: 'Products Overview', external_link: 'https://example.com/products',
                              content: 'Core manages entitlements. Merchant handles billing. Hi5 handles support.')
  end
  let(:doc2) do
    create(:captain_document, assistant: assistant, account: account, status: :available,
                              name: 'ChurnIQ Guide', external_link: 'https://example.com/churniq',
                              content: 'ChurnIQ provides retention analytics and subscriber insights.')
  end
  let(:offerings) do
    [
      {
        'id' => 'core', 'name' => 'Core', 'kind' => 'product', 'purpose' => 'Manages subscriber entitlements.',
        'status' => 'auto',
        'evidence' => [{ 'document_id' => doc1.id, 'passage_id' => 'p0', 'quote' => 'Core manages entitlements.' }]
      },
      {
        'id' => 'merchant', 'name' => 'Merchant', 'kind' => 'product', 'purpose' => 'Handles billing and tax compliance.',
        'status' => 'auto',
        'evidence' => [{ 'document_id' => doc1.id, 'passage_id' => 'p0', 'quote' => 'Merchant handles billing.' }]
      },
      {
        'id' => 'hi5', 'name' => 'Hi5', 'kind' => 'service', 'purpose' => 'Handles subscriber support.',
        'status' => 'auto',
        'evidence' => [{ 'document_id' => doc1.id, 'passage_id' => 'p0', 'quote' => 'Hi5 handles support.' }]
      },
      {
        'id' => 'churniq', 'name' => 'ChurnIQ', 'kind' => 'product', 'purpose' => 'Provides retention analytics.',
        'status' => 'auto',
        'evidence' => [{ 'document_id' => doc2.id, 'passage_id' => 'p0', 'quote' => 'ChurnIQ provides retention analytics' }]
      }
    ]
  end

  before do
    assistant.create_knowledge_brief!(
      account: account,
      status: 'ready',
      published: {
        'schema_version' => 2,
        'revision' => 'rev-1',
        'document_ids' => [doc1.id, doc2.id],
        'overview' => { 'text' => 'We provide subscriber retention and billing products.', 'document_ids' => [doc1.id] },
        'topics' => [],
        'offerings' => offerings
      }
    )
  end

  it 'enumerates all approved products and services deterministically with source citations' do
    result = described_class.new(assistant: assistant, query: 'Tell me all your products and services').perform

    expect(result).to be_present
    expect(result[:response]).to include('**Core**', '**Merchant**', '**Hi5**', '**ChurnIQ**')
    expect(result[:sources].size).to eq(2)
  end

  it 'immediately omits offerings whose supporting document becomes disabled or agents_only' do
    doc2.update!(agents_only: true)

    result = described_class.new(assistant: assistant, query: 'What products do you offer?').perform

    expect(result[:response]).to include('**Core**', '**Merchant**', '**Hi5**')
    expect(result[:response]).not_to include('ChurnIQ')
  end

  it 'paginates when more than PAGE_SIZE offerings exist' do
    many_offerings = (1..25).map do |i|
      num = format('%02d', i)
      {
        'id' => "prod-#{num}", 'name' => "Product #{num}", 'kind' => 'product',
        'purpose' => "Purpose #{num}.", 'status' => 'auto',
        'evidence' => [{ 'document_id' => doc1.id, 'passage_id' => 'p0', 'quote' => 'Core manages entitlements.' }]
      }
    end
    assistant.knowledge_brief.update!(
      published: assistant.knowledge_brief.published.merge('offerings' => many_offerings)
    )

    page1 = described_class.new(assistant: assistant, query: 'List all products').perform
    expect(page1[:response]).to include('Showing 1–20 of 25')
    expect(page1[:response]).to include('**Product 01**', '**Product 20**')
    expect(page1[:response]).not_to include('**Product 21**')
    expect(page1[:suggested_replies].first['message']).to include('[cursor:20]')

    page2 = described_class.new(assistant: assistant, query: 'Show remaining offerings (21–25) [cursor:20]').perform
    expect(page2[:response]).to include('Showing 21–25 of 25')
    expect(page2[:response]).to include('**Product 21**', '**Product 25**')
  end
end

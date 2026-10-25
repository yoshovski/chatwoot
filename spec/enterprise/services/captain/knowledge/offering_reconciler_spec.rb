require 'rails_helper'

RSpec.describe Captain::Knowledge::OfferingReconciler do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:doc_core) do
    create(:captain_document, assistant: assistant, account: account, status: :available,
                              name: 'Cleeng Core & Merchant',
                              content: "Cleeng Core manages subscriber entitlements and identity.\n\n" \
                                       'Merchant handles global tax compliance, recurring billing, and payment gateways.')
  end
  let(:doc_hi5) do
    create(:captain_document, assistant: assistant, account: account, status: :available,
                              name: 'Hi5 Overview',
                              content: 'Hi5 is our AI-powered subscriber customer care service for media brands.')
  end

  describe '.passages_for' do
    it 'splits document content into numbered passages and tracks section coverage' do
      result = described_class.passages_for(doc_core)

      expect(result[:passages].size).to eq(2)
      expect(result[:passages].first['id']).to eq('p0')
      expect(result[:passages].first['text']).to include('Cleeng Core manages subscriber entitlements')
      expect(result[:total_sections]).to eq(2)
      expect(result[:inspected_sections]).to eq(2)
      expect(result[:partial]).to be(false)
    end
  end

  describe '#reconcile' do
    it 'verifies verbatim quotes, discards ungrounded claims, and merges aliases conservatively' do
      raw = [
        {
          'name' => 'Cleeng Core',
          'kind' => 'product',
          'purpose' => 'Subscriber entitlement and identity management.',
          'aliases' => ['Core'],
          'evidence' => [{ 'document_id' => doc_core.id, 'passage_id' => 'p0',
                           'quote' => 'Cleeng Core manages subscriber entitlements and identity.' }]
        },
        {
          'name' => 'Core',
          'kind' => 'product',
          'purpose' => 'Manages subscriber entitlements and identity across platforms.',
          'evidence' => [{ 'document_id' => doc_core.id, 'passage_id' => 'p0',
                           'quote' => 'Cleeng Core manages subscriber entitlements and identity.' }]
        },
        {
          'name' => 'Hi5',
          'kind' => 'service',
          'purpose' => 'AI-powered subscriber customer care service.',
          'evidence' => [{ 'document_id' => doc_hi5.id, 'passage_id' => 'p0',
                           'quote' => 'Hi5 is our AI-powered subscriber customer care service for media brands.' }]
        },
        {
          'name' => 'Hallucinated Cloud',
          'kind' => 'product',
          'purpose' => 'Does not exist in source text.',
          'evidence' => [{ 'document_id' => doc_core.id, 'passage_id' => 'p0',
                           'quote' => 'Quote that does not appear anywhere in the document.' }]
        }
      ]

      reconciled = described_class.new(documents: [doc_core, doc_hi5]).reconcile(raw)

      expect(reconciled.pluck('name')).to eq(['Cleeng Core', 'Hi5'])
      core = reconciled.find { |item| item['name'] == 'Cleeng Core' }
      expect(core['aliases']).to include('Core')
      expect(core['evidence'].first['content_fingerprint']).to eq(Digest::SHA256.hexdigest(doc_core.content))
    end

    it 'preserves owner edits and rejections across regenerations while supporting evidence remains valid' do
      published = {
        'offerings' => [
          {
            'id' => 'cleeng-core',
            'name' => 'Cleeng Core (Custom Name)',
            'kind' => 'product',
            'purpose' => 'Owner-edited purpose for Cleeng Core.',
            'status' => 'owner_edited'
          },
          {
            'id' => 'hi5',
            'name' => 'Hi5',
            'kind' => 'service',
            'purpose' => 'AI-powered subscriber care.',
            'status' => 'rejected'
          }
        ]
      }
      raw = [
        {
          'name' => 'Cleeng Core',
          'kind' => 'product',
          'purpose' => 'Auto-extracted purpose.',
          'evidence' => [{ 'document_id' => doc_core.id, 'passage_id' => 'p0',
                           'quote' => 'Cleeng Core manages subscriber entitlements and identity.' }]
        },
        {
          'name' => 'Hi5',
          'kind' => 'service',
          'purpose' => 'Auto-extracted Hi5 purpose.',
          'evidence' => [{ 'document_id' => doc_hi5.id, 'passage_id' => 'p0',
                           'quote' => 'Hi5 is our AI-powered subscriber customer care service for media brands.' }]
        }
      ]

      reconciled = described_class.new(documents: [doc_core, doc_hi5], existing_published: published).reconcile(raw)

      core = reconciled.find { |item| item['id'] == 'cleeng-core' }
      hi5 = reconciled.find { |item| item['id'] == 'hi5' }
      expect(core).to include('name' => 'Cleeng Core (Custom Name)', 'purpose' => 'Owner-edited purpose for Cleeng Core.', 'status' => 'owner_edited')
      expect(hi5['status']).to eq('rejected')
    end
  end
end

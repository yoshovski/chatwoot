# frozen_string_literal: true

require 'spec_helper'
require 'active_support/all'

module Captain; end
class Captain::AssistantResponse; end unless defined?(Captain::AssistantResponse)
module Captain::Knowledge; end

require_relative '../../../../../enterprise/app/services/captain/knowledge/search'

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe Captain::Knowledge::Search do
  describe Captain::Knowledge::Search::Passage do
    describe '#source_reference' do
      it 'returns faq:<id> for faq kind' do
        passage = described_class.new(kind: 'faq', record: double('Record', id: 42))
        expect(passage.source_reference).to eq('faq:42')
      end

      it 'returns doc:<id> for document kind' do
        passage = described_class.new(kind: 'document', record: double('Record', id: 99))
        expect(passage.source_reference).to eq('doc:99')
      end

      it 'returns extra:<document_id> for extra kind' do
        passage = described_class.new(kind: 'extra', document_id: 'dify-doc-123')
        expect(passage.source_reference).to eq('extra:dify-doc-123')
      end

      it 'returns product:<handle> for product kind with handle' do
        passage = described_class.new(kind: 'product', handle: 'silk-scarf', document_id: 'doc-99')
        expect(passage.source_reference).to eq('product:silk-scarf')
      end

      it 'returns product:<handle> for catalog kind with handle' do
        passage = described_class.new(kind: 'catalog', handle: 'leather-wallet', document_id: 'doc-100')
        expect(passage.source_reference).to eq('product:leather-wallet')
      end

      it 'falls back to document_id for product kind without handle' do
        passage = described_class.new(kind: 'product', handle: nil, document_id: 'fallback-handle')
        expect(passage.source_reference).to eq('product:fallback-handle')
      end
    end
  end

  describe '#search datasets' do
    let(:account) { double('Account', id: 1, hooks: hooks_relation) }
    let(:hooks_relation) { double('HooksRelation') }
    let(:assistant) do
      double(
        'Assistant',
        account: account,
        account_id: 1,
        id: 10,
        config: {
          'dify_faq_dataset_id' => 'faq-ds',
          'dify_docs_dataset_id' => 'docs-ds',
          'dify_extra_dataset_ids' => ['extra-ds']
        }
      )
    end
    let(:search_service) { described_class.new(assistant) }
    let(:knowledge_client) { double('AiAgents::KnowledgeClient') }
    let(:knowledge_response) do
      double('Response', code: 200, parsed_response: { 'passages' => [] })
    end

    before do
      stub_const('AiAgents::KnowledgeClient', Class.new do
        def initialize(account:, actor:); end
      end)
      allow(assistant).to receive(:ensure_dify_datasets!)
      allow(AiAgents::KnowledgeClient).to receive(:new).with(account: account, actor: assistant).and_return(knowledge_client)
    end

    context 'when Shopify hook is connected with catalog dataset' do
      let(:hook) do
        double(
          'Integrations::Hook',
          shopify_connected?: true,
          shopify_catalog_sync_enabled?: true,
          shopify_catalog_dataset_id: 'catalog-ds-123'
        )
      end

      before do
        allow(hooks_relation).to receive(:find_by).with(app_id: 'shopify').and_return(hook)
      end

      it 'includes catalog dataset in search request' do
        expected_datasets = [
          { dataset_id: 'faq-ds', kind: 'faq', limit: 6 },
          { dataset_id: 'docs-ds', kind: 'document', limit: 6 },
          { dataset_id: 'extra-ds', kind: 'extra', limit: 6 },
          { dataset_id: 'catalog-ds-123', kind: 'catalog', limit: 6 }
        ]

        expect(knowledge_client).to receive(:request).with(
          method: :post,
          path: '/v1/knowledge/search',
          action: 'knowledge:read',
          payload: { account_id: 1, query: 'linen shirt', datasets: expected_datasets }
        ).and_return(knowledge_response)

        search_service.search('linen shirt')
      end

      it 'filters catalog out when kinds excludes catalog and product' do
        expected_datasets = [
          { dataset_id: 'docs-ds', kind: 'document', limit: 6 }
        ]

        expect(knowledge_client).to receive(:request).with(
          method: :post,
          path: '/v1/knowledge/search',
          action: 'knowledge:read',
          payload: { account_id: 1, query: 'linen shirt', datasets: expected_datasets }
        ).and_return(knowledge_response)

        search_service.search('linen shirt', kinds: ['document'])
      end

      it 'preserves catalog when kinds includes product' do
        expected_datasets = [
          { dataset_id: 'catalog-ds-123', kind: 'catalog', limit: 6 }
        ]

        expect(knowledge_client).to receive(:request).with(
          method: :post,
          path: '/v1/knowledge/search',
          action: 'knowledge:read',
          payload: { account_id: 1, query: 'linen shirt', datasets: expected_datasets }
        ).and_return(knowledge_response)

        search_service.search('linen shirt', kinds: ['product'])
      end

      it 'parses catalog passages and resolves product citation URL' do
        catalog_response = double(
          'Response',
          code: 200,
          parsed_response: {
            'passages' => [
              {
                'kind' => 'catalog',
                'title' => 'Silk Scarf',
                'content' => '100% mulberry silk scarf.',
                'score' => 0.92,
                'document_id' => 'prod-doc-1',
                'dataset_id' => 'catalog-ds-123',
                'handle' => 'silk-scarf'
              }
            ]
          }
        )

        allow(knowledge_client).to receive(:request).and_return(catalog_response)
        citation_sources = double('Captain::Knowledge::CitationSources')
        stub_const('Captain::Knowledge::CitationSources', Class.new do
          def initialize(assistant); end
        end)
        allow(Captain::Knowledge::CitationSources).to receive(:new).with(assistant).and_return(citation_sources)
        allow(citation_sources).to receive(:url).with('product:silk-scarf', anything)
                                                .and_return('https://store.myshopify.com/products/silk-scarf')

        results = search_service.search('silk')
        expect(results.size).to eq(1)
        expect(results.first.kind).to eq('catalog')
        expect(results.first.source_reference).to eq('product:silk-scarf')
        expect(results.first.source_url).to eq('https://store.myshopify.com/products/silk-scarf')
      end
    end

    context 'when Shopify catalog sync is paused' do
      let(:hook) do
        double(
          'Integrations::Hook',
          shopify_connected?: true,
          shopify_catalog_sync_enabled?: false,
          shopify_catalog_dataset_id: 'catalog-ds-123'
        )
      end

      before do
        allow(hooks_relation).to receive(:find_by).with(app_id: 'shopify').and_return(hook)
      end

      it 'removes catalog dataset from search request' do
        expected_datasets = [
          { dataset_id: 'faq-ds', kind: 'faq', limit: 6 },
          { dataset_id: 'docs-ds', kind: 'document', limit: 6 },
          { dataset_id: 'extra-ds', kind: 'extra', limit: 6 }
        ]

        expect(knowledge_client).to receive(:request).with(
          method: :post,
          path: '/v1/knowledge/search',
          action: 'knowledge:read',
          payload: { account_id: 1, query: 'linen shirt', datasets: expected_datasets }
        ).and_return(knowledge_response)

        search_service.search('linen shirt')
      end
    end

    context 'when Shopify is disconnected' do
      let(:hook) do
        double(
          'Integrations::Hook',
          shopify_connected?: false,
          shopify_catalog_sync_enabled?: true,
          shopify_catalog_dataset_id: 'catalog-ds-123'
        )
      end

      before do
        allow(hooks_relation).to receive(:find_by).with(app_id: 'shopify').and_return(hook)
      end

      it 'does not include catalog dataset in search request' do
        expected_datasets = [
          { dataset_id: 'faq-ds', kind: 'faq', limit: 6 },
          { dataset_id: 'docs-ds', kind: 'document', limit: 6 },
          { dataset_id: 'extra-ds', kind: 'extra', limit: 6 }
        ]

        expect(knowledge_client).to receive(:request).with(
          method: :post,
          path: '/v1/knowledge/search',
          action: 'knowledge:read',
          payload: { account_id: 1, query: 'linen shirt', datasets: expected_datasets }
        ).and_return(knowledge_response)

        search_service.search('linen shirt')
      end
    end

    context 'when Shopify hook does not exist' do
      before do
        allow(hooks_relation).to receive(:find_by).with(app_id: 'shopify').and_return(nil)
      end

      it 'does not include catalog dataset in search request' do
        expected_datasets = [
          { dataset_id: 'faq-ds', kind: 'faq', limit: 6 },
          { dataset_id: 'docs-ds', kind: 'document', limit: 6 },
          { dataset_id: 'extra-ds', kind: 'extra', limit: 6 }
        ]

        expect(knowledge_client).to receive(:request).with(
          method: :post,
          path: '/v1/knowledge/search',
          action: 'knowledge:read',
          payload: { account_id: 1, query: 'linen shirt', datasets: expected_datasets }
        ).and_return(knowledge_response)

        search_service.search('linen shirt')
      end
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles

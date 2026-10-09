# frozen_string_literal: true

require 'rails_helper'

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

    context 'when searching document passages' do
      let(:documents_scope) { double('DocumentsScope') }
      let(:account_documents_scope) { double('AccountDocumentsScope') }
      let(:enabled_documents_scope) { double('EnabledDocumentsScope') }
      let(:available_documents_scope) { double('AvailableDocumentsScope') }
      let(:doc_record) do
        double(
          'Captain::Document',
          id: 5,
          name: 'Guide',
          external_link: 'https://example.com/guide',
          visible_to_customers?: true
        )
      end
      let(:docs_response) do
        double(
          'Response',
          code: 200,
          parsed_response: {
            'passages' => [
              {
                'kind' => 'document',
                'title' => 'Guide',
                'content' => 'Guide content here.',
                'score' => 0.88,
                'document_id' => 'dify-doc-99',
                'dataset_id' => 'docs-ds',
                'url' => 'https://example.com/guide'
              }
            ]
          }
        )
      end

      before do
        allow(hooks_relation).to receive(:find_by).with(app_id: 'shopify').and_return(nil)
        allow(assistant).to receive(:documents).and_return(documents_scope)
        allow(documents_scope).to receive(:for_account).with(1).and_return(account_documents_scope)
        allow(account_documents_scope).to receive(:enabled).and_return(enabled_documents_scope)
        allow(enabled_documents_scope).to receive(:available).and_return(available_documents_scope)

        citation_sources = double('Captain::Knowledge::CitationSources')
        stub_const('Captain::Knowledge::CitationSources', Class.new do
          def initialize(assistant); end
        end)
        allow(Captain::Knowledge::CitationSources).to receive(:new).with(assistant).and_return(citation_sources)
        allow(citation_sources).to receive(:url).and_return('https://example.com/guide')
      end

      it 'returns the document when enabled, and excludes it when paused for both customers and agents' do
        allow(knowledge_client).to receive(:request).and_return(docs_response)

        # Enabled: document is found
        allow(available_documents_scope).to receive(:find_by).with("metadata->>'dify_document_id' = ?", 'dify-doc-99').and_return(doc_record)
        results = search_service.search('guide')
        expect(results.size).to eq(1)
        expect(results.first.record).to eq(doc_record)

        # Paused: enabled scope filters it out, returning nil
        allow(available_documents_scope).to receive(:find_by).with("metadata->>'dify_document_id' = ?", 'dify-doc-99').and_return(nil)
        expect(search_service.search('guide')).to be_empty

        # Paused: even for agents (for_agents: true), paused document is excluded
        search_service_for_agents = described_class.new(assistant, for_agents: true)
        expect(search_service_for_agents.search('guide')).to be_empty

        # Resumed: found again
        allow(available_documents_scope).to receive(:find_by).with("metadata->>'dify_document_id' = ?", 'dify-doc-99').and_return(doc_record)
        expect(search_service.search('guide').size).to eq(1)
      end
    end

    context 'when searching FAQ passages' do
      let(:responses_scope) { double('ResponsesScope') }
      let(:approved_responses_scope) { double('ApprovedResponsesScope') }
      let(:enabled_responses_scope) { double('EnabledResponsesScope') }
      let(:account_responses_scope) { double('AccountResponsesScope') }
      let(:faq_record) do
        double(
          'Captain::AssistantResponse',
          id: 42,
          question: 'How to return?',
          answer: 'Return within 30 days',
          visible_to_customers?: true
        )
      end
      let(:faq_response) do
        double(
          'Response',
          code: 200,
          parsed_response: {
            'passages' => [
              {
                'kind' => 'faq',
                'title' => 'How to return?',
                'content' => "Question: How to return?\nAnswer: Return within 30 days",
                'score' => 0.95,
                'document_id' => 'dify-faq-42',
                'dataset_id' => 'faq-ds'
              }
            ]
          }
        )
      end

      before do
        allow(hooks_relation).to receive(:find_by).with(app_id: 'shopify').and_return(nil)
        allow(assistant).to receive(:responses).and_return(responses_scope)
        allow(responses_scope).to receive(:approved).and_return(approved_responses_scope)
        allow(approved_responses_scope).to receive(:enabled_for_search).and_return(enabled_responses_scope)
        allow(enabled_responses_scope).to receive(:by_account).with(1).and_return(account_responses_scope)

        citation_sources = double('Captain::Knowledge::CitationSources')
        stub_const('Captain::Knowledge::CitationSources', Class.new do
          def initialize(assistant); end
        end)
        allow(Captain::Knowledge::CitationSources).to receive(:new).with(assistant).and_return(citation_sources)
        allow(citation_sources).to receive(:url).and_return('https://example.com/guide')
      end

      it 'returns the FAQ when enabled, and excludes it when paused for both customers and agents' do
        allow(knowledge_client).to receive(:request).and_return(faq_response)

        # Enabled
        allow(account_responses_scope).to receive(:find_by).with(dify_document_id: 'dify-faq-42').and_return(faq_record)
        results = search_service.search('return')
        expect(results.size).to eq(1)
        expect(results.first.record).to eq(faq_record)

        # Paused: enabled_for_search filters it out, returning nil
        allow(account_responses_scope).to receive(:find_by).with(dify_document_id: 'dify-faq-42').and_return(nil)
        expect(search_service.search('return')).to be_empty

        # Paused: even for agents
        search_service_for_agents = described_class.new(assistant, for_agents: true)
        expect(search_service_for_agents.search('return')).to be_empty

        # Resumed
        allow(account_responses_scope).to receive(:find_by).with(dify_document_id: 'dify-faq-42').and_return(faq_record)
        expect(search_service.search('return').size).to eq(1)
      end
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles

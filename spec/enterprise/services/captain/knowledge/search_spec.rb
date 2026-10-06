# frozen_string_literal: true

require 'spec_helper'
require 'active_support/all'

module Captain; end
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
end
# rubocop:enable RSpec/VerifiedDoubles

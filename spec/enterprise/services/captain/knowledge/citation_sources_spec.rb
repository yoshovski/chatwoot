# frozen_string_literal: true

require 'spec_helper'
require 'active_support/all'

module Captain; end
module Captain::Knowledge; end

require_relative '../../../../../enterprise/app/services/captain/knowledge/citation_sources'

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe Captain::Knowledge::CitationSources do
  subject(:citation_sources) { described_class.new(assistant) }

  let(:account) { double('Account') }
  let(:assistant) { double('Captain::Assistant', account: account, id: 1, account_id: 1, config: {}) }
  let(:hooks_relation) { double('hooks_relation') }

  before do
    allow(account).to receive(:hooks).and_return(hooks_relation)
  end

  describe '#url for product citations' do
    context 'when account has a connected Shopify hook' do
      let(:hook) do
        double(
          'Integrations::Hook',
          app_id: 'shopify',
          shopify_connected?: true,
          reference_id: 'test-store.myshopify.com',
          shopify_storefront_url: nil
        )
      end

      before do
        allow(hooks_relation).to receive(:find_by).with(app_id: 'shopify').and_return(hook)
      end

      it 'resolves product:<handle> to the default storefront URL' do
        expect(citation_sources.url('product:cotton-tshirt')).to eq('https://test-store.myshopify.com/products/cotton-tshirt')
      end

      it 'resolves product:<handle> using custom storefront_url when configured' do
        allow(hook).to receive(:shopify_storefront_url).and_return('https://custombrand.example.com')
        expect(citation_sources.url('product:red-sneakers')).to eq('https://custombrand.example.com/products/red-sneakers')
      end

      it 'ensures https scheme if storefront_url is missing a protocol' do
        allow(hook).to receive(:shopify_storefront_url).and_return('store.example.com')
        expect(citation_sources.url('product:blue-jeans')).to eq('https://store.example.com/products/blue-jeans')
      end

      it 'returns nil for empty or blank handle' do
        expect(citation_sources.url('product:')).to be_nil
        expect(citation_sources.url('product:   ')).to be_nil
      end
    end

    context 'when account has an unconnected Shopify hook' do
      let(:hook) do
        double(
          'Integrations::Hook',
          app_id: 'shopify',
          shopify_connected?: false,
          reference_id: 'test-store.myshopify.com'
        )
      end

      before do
        allow(hooks_relation).to receive(:find_by).with(app_id: 'shopify').and_return(hook)
      end

      it 'returns nil when hook is not connected' do
        expect(citation_sources.url('product:cotton-tshirt')).to be_nil
      end
    end

    context 'when account has no Shopify hook' do
      before do
        allow(hooks_relation).to receive(:find_by).with(app_id: 'shopify').and_return(nil)
      end

      it 'returns nil' do
        expect(citation_sources.url('product:cotton-tshirt')).to be_nil
      end
    end
  end

  describe '#urls mapping' do
    let(:hook) do
      double(
        'Integrations::Hook',
        app_id: 'shopify',
        shopify_connected?: true,
        reference_id: 'store.myshopify.com',
        shopify_storefront_url: nil
      )
    end

    before do
      allow(hooks_relation).to receive(:find_by).with(app_id: 'shopify').and_return(hook)
    end

    it 'transforms product references dictionary to numeric keys with URLs' do
      references = { '1' => 'product:item-one', '2' => 'product:item-two' }
      expect(citation_sources.urls(references)).to eq(
        1 => 'https://store.myshopify.com/products/item-one',
        2 => 'https://store.myshopify.com/products/item-two'
      )
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles

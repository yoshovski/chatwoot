require 'rails_helper'

RSpec.describe Captain::Documents::CrawlScope do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }

  context 'when the crawl starts on the connected Shopify store' do
    let(:document) { create(:captain_document, account: account, assistant: assistant, external_link: 'https://acme-store.com/policies/shipping-policy') }
    let(:scope) { described_class.new(document) }

    before do
      create(:integrations_hook, :shopify, account: account, reference_id: 'acme-dev.myshopify.com',
                                           settings: { 'state' => 'connected', 'storefront_url' => 'https://acme-store.com' })
    end

    it 'follows only content pages on the store' do
      followed = %w[
        https://acme-store.com/pages/contact https://www.acme-store.com/policies/refund-policy
        https://acme-store.com/blogs/news https://acme-store.com/en/pages/warranty
        https://acme-store.com/products/x200-battery https://acme-store.com/collections/batteries
        https://acme-store.com https://acme-store.com/cart https://acme-store.com/search
        https://facebook.com/acme https://other.example.com/pages/contact
      ].select { |link| scope.follow?(link) }

      expect(followed).to eq(%w[
                               https://acme-store.com/pages/contact https://www.acme-store.com/policies/refund-policy
                               https://acme-store.com/blogs/news https://acme-store.com/en/pages/warranty
                             ])
    end

    it 'adds a store page alone unless linked pages were asked for' do
      expect(scope.follow_links?).to be(false)
      document.include_linked_pages = 'true'
      expect(described_class.new(document).follow_links?).to be(true)
    end

    it 'limits a Firecrawl crawl to the same content pages' do
      expect(scope.firecrawl_include_paths).to eq([described_class::STORE_CONTENT_PATH])
    end
  end

  context 'when the crawl starts on any other site' do
    let(:document) { create(:captain_document, account: account, assistant: assistant, external_link: 'https://help.example.com/start') }
    let(:scope) { described_class.new(document) }

    it 'follows linked pages unless the document was added alone' do
      expect(scope.follow_links?).to be(true)
      document.include_linked_pages = 'false'
      expect(described_class.new(document).follow_links?).to be(false)
    end

    it 'follows every page on the same site and nothing else' do
      expect(scope.follow?('https://help.example.com/products/pricing')).to be(true)
      expect(scope.follow?('https://example.com/start')).to be(false)
      expect(scope.follow?('https://twitter.com/example')).to be(false)
      expect(scope.firecrawl_include_paths).to eq([])
    end
  end
end

require 'rails_helper'

RSpec.describe Captain::Documents::CrawlScope do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }

  context 'when the crawl starts on the connected Shopify store' do
    let(:document) { create(:captain_document, account: account, assistant: assistant, external_link: 'https://scanixx.com/policies/shipping-policy') }
    let(:scope) { described_class.new(document) }

    before do
      create(:integrations_hook, :shopify, account: account, reference_id: 'scanixx-dev.myshopify.com',
                                           settings: { 'state' => 'connected', 'storefront_url' => 'https://scanixx.com' })
    end

    it 'follows only content pages on the store' do
      followed = %w[
        https://scanixx.com/pages/contact https://www.scanixx.com/policies/refund-policy
        https://scanixx.com/blogs/news https://scanixx.com/en/pages/warranty
        https://scanixx.com/products/db2160 https://scanixx.com/collections/agras
        https://scanixx.com https://scanixx.com/cart https://scanixx.com/search
        https://facebook.com/scanixx https://other.example.com/pages/contact
      ].select { |link| scope.follow?(link) }

      expect(followed).to eq(%w[
                               https://scanixx.com/pages/contact https://www.scanixx.com/policies/refund-policy
                               https://scanixx.com/blogs/news https://scanixx.com/en/pages/warranty
                             ])
    end

    it 'limits a Firecrawl crawl to the same content pages' do
      expect(scope.firecrawl_include_paths).to eq([described_class::STORE_CONTENT_PATH])
    end
  end

  context 'when the crawl starts on any other site' do
    let(:document) { create(:captain_document, account: account, assistant: assistant, external_link: 'https://help.example.com/start') }
    let(:scope) { described_class.new(document) }

    it 'follows every page on the same site and nothing else' do
      expect(scope.follow?('https://help.example.com/products/pricing')).to be(true)
      expect(scope.follow?('https://example.com/start')).to be(false)
      expect(scope.follow?('https://twitter.com/example')).to be(false)
      expect(scope.firecrawl_include_paths).to eq([])
    end
  end
end

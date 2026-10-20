require 'rails_helper'

RSpec.describe Captain::Websites::PageRules do
  describe '.reason' do
    it 'marks API, auth, sandbox, status and demo hosts as technical' do
      %w[https://api.example.com/v1 https://auth.api.prod.example.com https://mediastoreapi.example.com
         https://srm-sandbox.example.com https://status.example.com https://sdk-demo.example.com].each do |url|
        expect(described_class.reason(url)).to eq('technical_host'), url
      end
    end

    it 'marks utility, listing and query URLs' do
      expect(described_class.reason('https://example.com/account/settings')).to eq('utility')
      expect(described_class.reason('https://example.com/hc/en-us/categories/1-Billing')).to eq('listing')
      expect(described_class.reason('https://example.com/blog/page/2')).to eq('listing')
      expect(described_class.reason('https://example.com/2019/04')).to eq('listing')
      expect(described_class.reason('https://example.com/pricing?plan=pro')).to eq('query')
    end

    it 'leaves content pages and support hosts alone' do
      expect(described_class.reason('https://www.example.com/pricing')).to be_nil
      expect(described_class.reason('https://publisher.support.example.com/hc/en-us/articles/1-Setup')).to be_nil
      expect(described_class.reason('https://developers.example.com/docs/payments')).to be_nil
    end
  end

  describe '.section' do
    it 'skips help-centre and locale prefixes' do
      expect(described_class.section('https://support.example.com/hc/en-us/articles/1-Setup')).to eq('support.example.com/articles')
      expect(described_class.section('https://www.example.com/de/pricing/pro')).to eq('example.com/pricing')
      expect(described_class.section('https://www.example.com')).to eq('example.com')
    end
  end

  it 'reads the path locale as a language code' do
    expect(described_class.locale('https://example.com/hc/fr-fr/articles/1')).to eq('fr')
    expect(described_class.locale('https://example.com/docs/payments')).to be_nil
  end

  it 'recognises support hosts' do
    expect(described_class.support_host?('publisher.support.example.com')).to be(true)
    expect(described_class.support_host?('blog.example.com')).to be(false)
  end
end

require 'rails_helper'

RSpec.describe AccountSignup do
  describe '.business_domain' do
    it 'keeps a business domain and drops free mail' do
      expect(described_class.business_domain('anna@Shop.example')).to eq('shop.example')
      expect(described_class.business_domain('anna@gmail.com')).to be_nil
    end
  end

  describe '.website_domain' do
    it 'reads the host without www, with or without a scheme' do
      expect(described_class.website_domain('https://www.Shop.example/about')).to eq('shop.example')
      expect(described_class.website_domain('shop.example')).to eq('shop.example')
      expect(described_class.website_domain('')).to be_nil
    end
  end

  describe '.trial_used_for?' do
    let!(:first) { described_class.create!(email_domain: 'shop.example', trial_granted: true) }

    it 'matches a trial on the email domain or the website domain' do
      described_class.create!(website_domain: 'other.example', trial_granted: true)

      expect(described_class.trial_used_for?('shop.example')).to be(true)
      expect(described_class.trial_used_for?('other.example')).to be(true)
      expect(described_class.trial_used_for?('new.example')).to be(false)
      expect(described_class.trial_used_for?('shop.example', except: first)).to be(false)
    end

    it 'ignores signups that did not get the trial' do
      first.update!(trial_granted: false)

      expect(described_class.trial_used_for?('shop.example')).to be(false)
    end
  end
end

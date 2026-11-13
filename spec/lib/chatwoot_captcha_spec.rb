require 'rails_helper'

describe ChatwootCaptcha do
  # Installation configs are cached in Redis, which the example's rollback does not clear.
  after { GlobalConfig.clear_cache }

  let(:verify_response) { instance_double(HTTParty::Response, success?: true, parsed_response: { 'success' => true }) }

  it 'is valid without a captcha secret, and not configured' do
    expect(described_class.new('random_key').valid?).to be(true)
    expect(described_class.configured?).to be(false)
  end

  context 'when the hCaptcha secret is set' do
    before { create(:installation_config, name: 'HCAPTCHA_SERVER_KEY', value: 'hcaptcha_secret') }

    it 'refuses a blank token' do
      expect(described_class.new('').valid?).to be false
    end

    it 'checks the token with hCaptcha' do
      allow(HTTParty).to receive(:post).and_return(verify_response)

      expect(described_class.new('valid_response', remote_ip: '1.2.3.4').valid?).to be true
      expect(HTTParty).to have_received(:post)
        .with('https://hcaptcha.com/siteverify', body: { response: 'valid_response', secret: 'hcaptcha_secret', remoteip: '1.2.3.4' }, timeout: 10)
    end

    it 'refuses when the check fails or times out' do
      allow(HTTParty).to receive(:post).and_return(instance_double(HTTParty::Response, success?: true, parsed_response: { 'success' => false }))
      expect(described_class.new('bad').valid?).to be false

      allow(HTTParty).to receive(:post).and_raise(Net::ReadTimeout)
      expect(described_class.new('slow').valid?).to be false
    end
  end

  context 'when the Turnstile secret is set too' do
    before do
      create(:installation_config, name: 'HCAPTCHA_SERVER_KEY', value: 'hcaptcha_secret')
      create(:installation_config, name: 'TURNSTILE_SECRET_KEY', value: 'turnstile_secret')
      create(:installation_config, name: 'TURNSTILE_SITE_KEY', value: 'turnstile_site')
    end

    it 'uses Turnstile and gives the page its site key' do
      allow(HTTParty).to receive(:post).and_return(verify_response)

      expect(described_class.new('token').valid?).to be true
      expect(HTTParty).to have_received(:post)
        .with('https://challenges.cloudflare.com/turnstile/v0/siteverify', body: { response: 'token', secret: 'turnstile_secret' }, timeout: 10)
      expect(described_class.frontend_config).to eq(provider: 'turnstile', site_key: 'turnstile_site')
    end
  end
end

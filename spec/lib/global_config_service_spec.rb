require 'rails_helper'

describe GlobalConfigService do
  subject(:trigger) { described_class }

  describe 'execute' do
    context 'when called with default options' do
      before do
        # to clear redis cache
        GlobalConfig.clear_cache
      end

      # it 'set default value if not found on db nor env var' do
      #   value = GlobalConfig.get('ENABLE_ACCOUNT_SIGNUP')
      #   expect(value['ENABLE_ACCOUNT_SIGNUP']).to eq nil

      #   described_class.load('ENABLE_ACCOUNT_SIGNUP', 'true')

      #   value = GlobalConfig.get('ENABLE_ACCOUNT_SIGNUP')
      #   expect(value['ENABLE_ACCOUNT_SIGNUP']).to eq 'true'
      #   expect(InstallationConfig.find_by(name: 'ENABLE_ACCOUNT_SIGNUP')&.value).to eq 'true'
      # end

      it 'get value from env variable even if present on DB' do
        with_modified_env ENABLE_ACCOUNT_SIGNUP: 'false' do
          expect(InstallationConfig.find_by(name: 'ENABLE_ACCOUNT_SIGNUP')&.value).to be_nil
          value = described_class.load('ENABLE_ACCOUNT_SIGNUP', 'true')
          expect(value).to eq 'false'
        end
      end

      # it 'get value from DB if found' do
      #   # Set a value in db first and make sure this value
      #   # is not respected even when load() method is called with
      #   # another value.
      #   InstallationConfig.where(name: 'ENABLE_ACCOUNT_SIGNUP').first_or_create(value: 'true')
      #   described_class.load('ENABLE_ACCOUNT_SIGNUP', 'false')
      #   value = GlobalConfig.get('ENABLE_ACCOUNT_SIGNUP')
      #   expect(value['ENABLE_ACCOUNT_SIGNUP']).to eq 'true'
      # end
    end
  end

  describe '.account_signup_enabled?' do
    before { GlobalConfig.clear_cache }

    after { GlobalConfig.clear_cache }

    it 'stays off without a captcha secret, even when ENABLE_ACCOUNT_SIGNUP is on' do
      with_modified_env ENABLE_ACCOUNT_SIGNUP: 'true' do
        expect(described_class.account_signup_enabled?).to be(false)
      end
    end

    it 'is on with ENABLE_ACCOUNT_SIGNUP and a captcha secret' do
      with_modified_env ENABLE_ACCOUNT_SIGNUP: 'true', TURNSTILE_SECRET_KEY: 'secret' do
        expect(described_class.account_signup_enabled?).to be(true)
      end
    end
  end
end

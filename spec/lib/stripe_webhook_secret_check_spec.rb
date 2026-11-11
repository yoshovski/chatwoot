require 'rails_helper'

RSpec.describe StripeWebhookSecretCheck do
  let(:production) { ActiveSupport::StringInquirer.new('production') }

  it 'refuses to boot production when billing is on and the webhook secret is blank' do
    env = { 'STRIPE_SECRET_KEY' => 'sk_test_stub', 'STRIPE_WEBHOOK_SECRET' => '' }

    expect { described_class.verify!(env: env, rails_env: production) }.to raise_error(StripeWebhookSecretCheck::MissingSecretError)
  end

  it 'boots production when the webhook secret is set' do
    env = { 'STRIPE_SECRET_KEY' => 'sk_test_stub', 'STRIPE_WEBHOOK_SECRET' => 'whsec_stub' }

    expect { described_class.verify!(env: env, rails_env: production) }.not_to raise_error
  end

  it 'boots production when billing is off' do
    expect { described_class.verify!(env: {}, rails_env: production) }.not_to raise_error
  end

  it 'does not check outside production' do
    env = { 'STRIPE_SECRET_KEY' => 'sk_test_stub' }

    expect { described_class.verify!(env: env, rails_env: ActiveSupport::StringInquirer.new('development')) }.not_to raise_error
  end
end

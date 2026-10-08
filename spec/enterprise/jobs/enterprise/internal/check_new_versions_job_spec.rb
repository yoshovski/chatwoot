require 'rails_helper'

RSpec.describe Internal::CheckNewVersionsJob do
  subject(:job) { described_class.perform_now }

  let(:reconsile_premium_config_service) { instance_double(Internal::ReconcilePlanConfigService) }

  before do
    allow(Internal::ReconcilePlanConfigService).to receive(:new).and_return(reconsile_premium_config_service)
    allow(reconsile_premium_config_service).to receive(:perform)
    allow(Rails.env).to receive(:production?).and_return(true)
  end

  # This fork keeps its own plan: the hub's plan and support settings are not written (see 3c02831aba).
  it 'does not store the plan info from the hub' do
    data = { 'version' => '1.2.3', 'plan' => 'community', 'plan_quantity' => 1, 'chatwoot_support_website_token' => '123',
             'chatwoot_support_identifier_hash' => '123', 'chatwoot_support_script_url' => '123' }
    allow(ChatwootHub).to receive(:sync_with_hub).and_return(data)
    job
    expect(InstallationConfig.where(name: %w[INSTALLATION_PRICING_PLAN CHATWOOT_SUPPORT_WEBSITE_TOKEN])).to be_empty
  end

  it 'calls Internal::ReconcilePlanConfigService' do
    data = { 'version' => '1.2.3' }
    allow(ChatwootHub).to receive(:sync_with_hub).and_return(data)
    job
    expect(reconsile_premium_config_service).to have_received(:perform)
  end
end

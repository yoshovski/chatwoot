require 'rails_helper'

RSpec.describe Integrations::App do
  let(:account) { create(:account) }
  let(:app) { described_class.find(id: 'hubspot') }

  it 'makes HubSpot active only when the HubSpot client id is configured' do
    allow(GlobalConfigService).to receive(:load).with('HUBSPOT_CLIENT_ID', nil).and_return(nil)
    expect(app.active?(account)).to be false

    allow(GlobalConfigService).to receive(:load).with('HUBSPOT_CLIENT_ID', nil).and_return('client_id')
    expect(app.active?(account)).to be true
  end
end

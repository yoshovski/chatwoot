require 'rails_helper'

RSpec.describe Captain::LeadSettings do
  let(:assistant) { create(:captain_assistant) }
  let(:lead_config) { { 'leads_enabled' => true, 'lead_types' => [{ 'name' => 'Partner', 'rule' => 'Wants to partner' }] } }

  it 'still accepts agents saved with the removed per-agent HubSpot switch' do
    assistant.config = assistant.config.merge(lead_config, 'lead_hubspot_sync_enabled' => true)

    expect(assistant).to be_valid
  end

  it 'rejects a non-boolean leads switch' do
    assistant.config = assistant.config.merge(lead_config, 'leads_enabled' => 'yes')

    expect(assistant).not_to be_valid
  end
end

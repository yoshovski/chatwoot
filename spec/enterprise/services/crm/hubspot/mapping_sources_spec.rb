require 'rails_helper'

RSpec.describe Crm::Hubspot::MappingSources do
  let(:account) { create(:account) }

  it 'lists the fixed fields, agent lead fields and contact attributes once each' do
    create(:captain_assistant, account: account, config: {
             'leads_enabled' => true, 'lead_types' => [{ 'name' => 'Partner', 'rule' => 'Wants to partner' }],
             'lead_fields' => [{ 'key' => 'company', 'label' => 'Company' }]
           })
    create(:custom_attribute_definition, account: account, attribute_model: 'contact_attribute',
                                         attribute_key: 'plan', attribute_display_name: 'Plan')
    create(:custom_attribute_definition, account: account, attribute_model: 'conversation_attribute',
                                         attribute_key: 'priority_level', attribute_display_name: 'Priority')

    sources = described_class.new(account).all

    expect(sources.first(7).pluck('key')).to eq(%w[email firstname lastname phone lead_type lead_summary lead_source])
    expect(sources.find { |source| source['key'] == 'lead_company' }).to eq('key' => 'lead_company', 'label' => 'Company', 'kind' => 'lead')
    expect(sources.find { |source| source['key'] == 'plan' }).to include('kind' => 'attribute')
    expect(sources.pluck('key')).not_to include('priority_level')
    expect(sources.pluck('key')).to eq(sources.pluck('key').uniq)
  end
end

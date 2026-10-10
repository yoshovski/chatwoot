require 'rails_helper'

RSpec.describe Captain::Dify::DatasetIdentity do
  let(:account) { create(:account, name: 'Acme') }
  let(:assistant) { create(:captain_assistant, account: account, name: 'Octave') }

  it 'leads with the account id and names account, agent and kind' do
    expect(described_class.new(assistant).attributes('faq')[:name]).to eq("##{account.id} Acme · Octave · FAQs")
  end

  it 'names an agent called like its account only once' do
    assistant.update!(name: 'acme')

    expect(described_class.new(assistant).attributes('docs')[:name]).to eq("##{account.id} Acme · Documents")
  end

  it 'shortens long names to fit Dify while keeping the id and the kind' do
    account.update!(name: 'A very long shop name that goes on and on')

    name = described_class.new(assistant).attributes('faq')[:name]
    expect(name.length).to eq(40)
    expect(name).to start_with("##{account.id} A very long").and end_with('… · FAQs')
  end
end

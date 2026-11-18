require 'rails_helper'

RSpec.describe Captain::Dify::DatasetIdentity do
  let(:account) { create(:account, name: 'Acme') }
  let(:assistant) { create(:captain_assistant, account: account, name: 'Octave') }

  it 'leads with the account and agent ids and names account, agent and kind' do
    expect(described_class.new(assistant).attributes('faq')[:name]).to eq("##{account.id}/#{assistant.id} Acme · Octave · FAQs")
  end

  it 'names an agent called like its account only once' do
    assistant.update!(name: 'acme')

    expect(described_class.new(assistant).attributes('docs')[:name]).to eq("##{account.id}/#{assistant.id} Acme · Documents")
  end

  it 'shortens long names to fit Dify while keeping the ids and the kind' do
    account.update!(name: 'A very long shop name that goes on and on')

    name = described_class.new(assistant).attributes('faq')[:name]
    expect(name.length).to eq(40)
    expect(name).to start_with("##{account.id}/#{assistant.id} A very long").and end_with('… · FAQs')
  end

  it 'gives two agents distinct dataset names when a long account name fills the label' do
    account.update!(name: 'A very long shop name that goes on and on')
    second_assistant = create(:captain_assistant, account: account, name: assistant.name)

    first_name = described_class.new(assistant).attributes('docs')[:name]
    second_name = described_class.new(second_assistant).attributes('docs')[:name]

    expect(first_name).not_to eq(second_name)
    expect([first_name.length, second_name.length]).to all(be <= 40)
  end
end

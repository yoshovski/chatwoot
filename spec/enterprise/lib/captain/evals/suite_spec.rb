require 'rails_helper'

RSpec.describe Captain::Evals::Suite do
  let(:data) do
    {
      'version' => 1,
      'business' => { 'name' => 'Northwind Outdoor', 'description' => 'Outdoor gear.',
                      'knowledge' => [{ 'title' => 'Returns', 'url' => 'https://northwind.test/returns', 'content' => '30 days.' }] },
      'cases' => [{ 'id' => 'N01', 'title' => 'Returns', 'message' => 'Can I return boots?',
                    'expect' => { 'route' => 'faq_kb', 'checks' => ['welcome_once', { 'max_chars' => 300 }] } }]
    }
  end

  it 'loads reply_basics with 14 cases' do
    suite = described_class.load('reply_basics')

    expect(suite.cases.pluck('id')).to eq(%w[R01 R02 R03 R04 R05 R06 R07 R08 R09 R10 R11 R12 R13 R14])
    expect(suite.business['name']).to eq('Acme Streaming Tools')
    expect(suite.defaults).to include('greeting_mode' => 'ai')
  end

  it 'adds the expected route to the checks' do
    suite = described_class.new('northwind', data)

    expect(suite.checks_for(suite.cases.first)).to eq(['welcome_once', { 'max_chars' => 300 }, { 'route' => 'faq_kb' }])
  end

  it 'selects cases with only' do
    data['cases'] << data['cases'].first.merge('id' => 'N02')

    expect(described_class.new('northwind', data).cases(only: ['N02']).pluck('id')).to eq(['N02'])
  end

  it 'keeps the SHA stable across key order' do
    reordered = data.to_a.reverse.to_h.merge('business' => data['business'].to_a.reverse.to_h)

    expect(described_class.new('a', reordered).sha256).to eq(described_class.new('b', data).sha256)
    expect(described_class.new('c', data.merge('version' => 1, 'defaults' => { 'tone' => 'short' })).sha256)
      .not_to eq(described_class.new('b', data).sha256)
  end

  it 'rejects an unknown check' do
    data['cases'].first['expect']['checks'] << 'sounds_nice'

    expect { described_class.new('northwind', data) }.to raise_error(described_class::Invalid, /unknown check sounds_nice/)
  end

  it 'rejects unknown case keys, duplicate ids and cases without checks' do
    expect { described_class.new('x', data.deep_merge('cases' => [data['cases'].first.merge('expct' => {})])) }
      .to raise_error(described_class::Invalid, /unknown keys expct/)
    expect { described_class.new('x', data.merge('cases' => data['cases'] * 2)) }.to raise_error(described_class::Invalid, /unique/)
    expect { described_class.new('x', data.merge('cases' => [data['cases'].first.merge('expect' => {})])) }
      .to raise_error(described_class::Invalid, /empty/)
  end

  it 'rejects a wrong version or missing business' do
    expect { described_class.new('x', data.merge('version' => 2)) }.to raise_error(described_class::Invalid, /version/)
    expect { described_class.new('x', data.merge('business' => { 'name' => 'Only a name' })) }.to raise_error(described_class::Invalid, /business/)
  end

  it 'raises for a missing suite' do
    expect { described_class.load('does_not_exist') }.to raise_error(described_class::Invalid, /not found/)
  end
end

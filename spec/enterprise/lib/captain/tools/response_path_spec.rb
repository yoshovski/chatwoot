require 'rails_helper'

RSpec.describe Captain::Tools::ResponsePath do
  let(:data) do
    { 'order' => { 'id' => 1042, 'email' => 'jane@example.com', 'tags' => ['gift'] },
      'items' => [{ 'sku' => 'A-1', 'qty' => 2 }, { 'sku' => 'B-2', 'qty' => 1 }],
      'meta' => { 'x.y' => 'dotted', 'say "hi"' => 'quoted' } }
  end

  it 'reads nested keys' do
    expect(described_class.dig(data, 'order.email')).to eq('jane@example.com')
  end

  it 'reads array indexes' do
    expect(described_class.dig(data, 'items[1].sku')).to eq('B-2')
    expect(described_class.dig(data, 'order.tags[0]')).to eq('gift')
  end

  it 'reads every item with [*]' do
    expect(described_class.dig(data, 'items[*].sku')).to eq(%w[A-1 B-2])
  end

  it 'reads quoted keys that hold dots or quotes' do
    expect(described_class.dig(data, 'meta["x.y"]')).to eq('dotted')
    expect(described_class.dig(data, 'meta["say \"hi\""]')).to eq('quoted')
  end

  it 'reads from a top-level array' do
    expect(described_class.dig(data['items'], '[0].qty')).to eq(2)
  end

  it 'returns nil for missing paths' do
    expect(described_class.dig(data, 'order.missing.deeper')).to be_nil
    expect(described_class.dig(data, 'items[5].sku')).to be_nil
    expect(described_class.dig(data, 'order[0]')).to be_nil
    expect(described_class.dig(data, 'order.email.length')).to be_nil
  end

  it 'returns nil for a non-JSON body' do
    expect(described_class.dig('plain text', 'order.id')).to be_nil
  end

  it 'rejects malformed paths' do
    expect(described_class.valid?('items[x]')).to be(false)
    expect(described_class.valid?('order..id')).to be(false)
    expect(described_class.valid?('')).to be(false)
    expect(described_class.dig(data, 'items[')).to be_nil
    expect(described_class.valid?('items[*].sku')).to be(true)
  end
end

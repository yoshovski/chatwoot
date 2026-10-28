require 'rails_helper'

RSpec.describe Captain::KnowledgeGaps::Normalizer do
  it 'ignores case, punctuation, emoji and filler words' do
    expect(described_class.call("Hi! What's the shipping cost to Spain? 🙂")).to eq('whats shipping cost to spain')
    expect(described_class.call('what’s the SHIPPING cost to spain')).to eq('whats shipping cost to spain')
  end

  it 'keeps non-Latin text' do
    expect(described_class.call('¿Cuánto cuesta el envío?')).to eq('cuánto cuesta el envío')
  end

  it 'keeps a question made only of filler words' do
    expect(described_class.call('Can you?')).to eq('can you')
  end
end

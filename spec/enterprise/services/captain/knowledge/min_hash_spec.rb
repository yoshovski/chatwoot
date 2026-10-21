require 'rails_helper'

RSpec.describe Captain::Knowledge::MinHash do
  let(:article) { (1..200).map { |index| "Fact #{index} about plans, invoices and support." }.join(' ') }

  it 'finds the same article with another footer near and an unrelated article not' do
    signature = described_class.of("#{article} Updated in May.")
    other = (1..200).map { |index| "Story #{index} about streaming, sports and fans." }.join(' ')

    expect(described_class.near?(signature, described_class.of("#{article} Contact our team."))).to be(true)
    expect(described_class.near?(signature, described_class.of(other))).to be(false)
  end

  it 'has no signature for text too short for one shingle' do
    expect(described_class.of('Two words')).to be_nil
  end
end

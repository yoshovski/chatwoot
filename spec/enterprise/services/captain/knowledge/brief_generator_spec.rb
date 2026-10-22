require 'rails_helper'

RSpec.describe Captain::Knowledge::BriefGenerator do
  let(:output) do
    { 'overview' => { 'text' => 'Cleeng runs subscriptions for publishers.', 'document_ids' => [1] },
      'topics' => [{ 'title' => 'Payments', 'summary' => 'Adyen and PayPal setup.', 'document_ids' => [1] }] }
  end

  it 'accepts a known business type or none' do
    expect(described_class.valid_output?(output, [1])).to be(true)
    expect(described_class.valid_output?(output.merge('business_type' => 'software'), [1])).to be(true)
  end

  it 'rejects an unknown business type' do
    expect(described_class.valid_output?(output.merge('business_type' => 'casino'), [1])).to be(false)
  end
end

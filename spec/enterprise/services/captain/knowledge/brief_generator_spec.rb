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

  describe '.normalize' do
    it 'removes inline document IDs and trims long text at a sentence end' do
      long = "#{'Refunds are reviewed case by case. ' * 12}Final words [341]."
      raw = output.merge('overview' => { 'text' => 'Cleeng runs subscriptions [1, 2].', 'document_ids' => [1] },
                         'topics' => [{ 'title' => 'Refunds', 'summary' => long, 'document_ids' => [1] }])

      normalized = described_class.normalize(raw, [1])

      expect(normalized.dig('overview', 'text')).to eq('Cleeng runs subscriptions.')
      summary = normalized['topics'].first['summary']
      expect(summary.length).to be <= described_class::TOPIC_LENGTH
      expect(summary).to end_with('case by case.')
      expect(described_class.valid_output?(normalized, [1])).to be(true)
    end

    it 'drops topics that stay invalid instead of failing the draft' do
      raw = output.merge('topics' => output['topics'] + [{ 'title' => 'Unknown', 'summary' => 'Text.', 'document_ids' => [99] }])

      expect(described_class.normalize(raw, [1])['topics'].pluck('title')).to eq(['Payments'])
    end
  end
end

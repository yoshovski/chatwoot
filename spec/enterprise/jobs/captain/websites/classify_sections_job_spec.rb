require 'rails_helper'

RSpec.describe Captain::Websites::ClassifySectionsJob do
  let(:assistant) { create(:captain_assistant) }
  let(:source) do
    Captain::WebsiteSource.create!(
      assistant: assistant, url: 'https://www.example.com', status: 'ready',
      discovery_stats: { 'run' => 'run-1', 'classification' => 'pending' },
      pages: [{ 'url' => 'https://blog.example.com/guide', 'section' => 'blog.example.com/guide', 'bucket' => 'maybe' }]
    )
  end
  let(:labels) { { 'blog.example.com/guide' => { 'label' => 'support', 'recommended' => true, 'reason' => 'Setup guides' } } }
  let(:classifier) { instance_double(Captain::Websites::SectionClassifier, perform: labels) }

  before { allow(Captain::Websites::SectionClassifier).to receive(:new).and_return(classifier) }

  it 'stores section labels and re-sorts the pages' do
    described_class.perform_now(source.id, 'run-1')

    expect(source.reload.discovery_stats).to include('classification' => 'done', 'sections' => labels)
    expect(source.pages.first['bucket']).to eq('recommended')
  end

  it 'ignores labels from an older discovery run' do
    described_class.perform_now(source.id, 'run-0')

    expect(Captain::Websites::SectionClassifier).not_to have_received(:new)
    expect(source.reload.discovery_stats['classification']).to eq('pending')
  end

  it 'keeps the rule-based sorting when classification fails' do
    allow(classifier).to receive(:perform).and_raise(Faraday::TimeoutError)
    described_class.perform_now(source.id, 'run-1')

    expect(source.reload.discovery_stats['classification']).to eq('failed')
    expect(source.pages.first['bucket']).to eq('maybe')
  end
end

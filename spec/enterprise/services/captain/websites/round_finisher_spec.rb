require 'rails_helper'

RSpec.describe Captain::Websites::RoundFinisher do
  let(:assistant) { create(:captain_assistant) }
  let(:stats) { { 'verification' => 'done', 'classification' => 'done', 'new_urls' => %w[https://www.example.com/new https://www.example.com/blog] } }
  let(:source) do
    Captain::WebsiteSource.create!(
      assistant: assistant, url: 'https://www.example.com', status: 'ready', discovery_stats: stats,
      selected_urls: %w[https://www.example.com/pricing],
      pages: [{ 'url' => 'https://www.example.com/pricing', 'bucket' => 'recommended' },
              { 'url' => 'https://www.example.com/old', 'bucket' => 'recommended' },
              { 'url' => 'https://www.example.com/new', 'bucket' => 'recommended' },
              { 'url' => 'https://www.example.com/blog', 'bucket' => 'maybe' }]
    )
  end

  describe '.claim?' do
    it 'lets only the first job that sees both results finish the round' do
      expect(described_class.claim?(source)).to be(true)
      expect(described_class.claim?(source.reload)).to be(false)
    end

    it 'waits for the section labels' do
      source.update!(discovery_stats: stats.merge('classification' => 'pending'))

      expect(described_class.claim?(source)).to be(false)
    end
  end

  describe '#perform' do
    it 'adds only new recommended pages to a saved selection' do
      described_class.new(source).perform

      expect(source.reload.selected_urls).to eq(%w[https://www.example.com/pricing https://www.example.com/new])
      expect(source.discovery_stats).to include('auto_added' => 1)
    end

    it 'adds nothing when the administrator turned it off or has not chosen pages yet' do
      source.update!(auto_add_pages: false)
      described_class.new(source).perform
      source.update!(auto_add_pages: true, selected_urls: [])
      described_class.new(source).perform

      expect(source.reload.selected_urls).to eq([])
    end

    it 'starts the next round when discovery stopped at a limit' do
      source.update!(discovery_stats: stats.merge('continue' => true))

      expect { described_class.new(source).perform }
        .to have_enqueued_job(Captain::Websites::DiscoverJob).with(source.id, 'continue')
    end
  end
end

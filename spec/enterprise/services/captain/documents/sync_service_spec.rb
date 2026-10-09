require 'rails_helper'

RSpec.describe Captain::Documents::SyncService do
  let(:url) { 'https://example.com/help/returns' }
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:validators) do
    { 'http_etag' => '"v1"', 'http_last_modified' => 'Wed, 01 Oct 2026 10:00:00 GMT', 'last_full_fetch_at' => 1.day.ago.iso8601 }
  end
  let(:document) do
    create(:captain_document, assistant: assistant, account: account, external_link: url, content: 'Old content', status: :available,
                              metadata: validators.merge('content_fingerprint' => 'old-fingerprint'))
  end
  let(:fetcher) do
    instance_double(Captain::Documents::SinglePageFetcher,
                    fetch: Captain::Documents::SinglePageFetcher::Result.new(success: true, title: 'Returns', content: 'New content'))
  end

  before do
    allow(Resolv).to receive(:getaddresses).and_call_original
    allow(Resolv).to receive(:getaddresses).with('example.com').and_return(['93.184.216.34'])
    allow(Captain::Documents::SinglePageFetcher).to receive(:new).and_return(fetcher)
  end

  context 'when Firecrawl is configured' do
    before { create(:installation_config, name: 'CAPTAIN_FIRECRAWL_API_KEY', value: 'test-key') }

    it 'skips the scrape when the page answers 304 Not Modified' do
      stub_request(:get, url).with(headers: { 'If-None-Match' => '"v1"', 'If-Modified-Since' => validators['http_last_modified'] })
                             .to_return(status: 304)

      expect(described_class.new(document).perform).to eq(:not_modified)

      expect(fetcher).not_to have_received(:fetch)
      expect(document.reload).to have_attributes(sync_status: 'synced', content: 'Old content', sync_step: nil)
      expect(document.metadata['last_full_fetch_at']).to eq(validators['last_full_fetch_at'])
    end

    it 'skips the scrape when a server ignores the conditional request but returns the same ETag' do
      stub_request(:get, url).to_return(status: 200, body: 'x' * 100, headers: { 'ETag' => 'W/"v1"' })

      expect(described_class.new(document).perform).to eq(:not_modified)

      expect(fetcher).not_to have_received(:fetch)
    end

    it 'scrapes and stores the new validators when the ETag changed' do
      stub_request(:get, url).to_return(status: 200, body: 'new', headers: { 'ETag' => '"v2"', 'Last-Modified' => 'Thu, 02 Oct 2026 10:00:00 GMT' })

      expect(described_class.new(document).perform).to eq(:updated)

      expect(fetcher).to have_received(:fetch)
      expect(document.reload.metadata).to include('http_etag' => '"v2"', 'http_last_modified' => 'Thu, 02 Oct 2026 10:00:00 GMT')
      expect(Time.zone.parse(document.metadata['last_full_fetch_at'])).to be_within(1.minute).of(Time.current)
    end

    it 'scrapes a page without stored validators and remembers the validators it sends' do
      document.update!(metadata: {})
      stub_request(:get, url).with { |request| request.headers.keys.map(&:downcase).exclude?('if-none-match') }
                             .to_return(status: 200, body: 'x', headers: { 'ETag' => '"v1"' })

      described_class.new(document).perform

      expect(fetcher).to have_received(:fetch)
      expect(document.reload.metadata).to include('http_etag' => '"v1"', 'last_full_fetch_at' => be_present)
    end

    it 'scrapes without a conditional request once the last full fetch is older than seven days' do
      document.update!(metadata: validators.merge('last_full_fetch_at' => 8.days.ago.iso8601))
      stub_request(:get, url).with { |request| request.headers.keys.map(&:downcase).exclude?('if-none-match') }
                             .to_return(status: 200, body: 'x', headers: { 'ETag' => '"v1"' })

      described_class.new(document).perform

      expect(fetcher).to have_received(:fetch)
      expect(Time.zone.parse(document.reload.metadata['last_full_fetch_at'])).to be_within(1.minute).of(Time.current)
    end

    it 'still scrapes and clears the validators when the pre-check times out' do
      stub_request(:get, url).to_timeout

      expect(described_class.new(document).perform).to eq(:updated)

      expect(fetcher).to have_received(:fetch)
      expect(document.reload.metadata).to include('http_etag' => nil, 'http_last_modified' => nil)
    end

    it 'records the validators when the scraped content is unchanged' do
      document.update!(content_fingerprint: Digest::SHA256.hexdigest('New content'))
      stub_request(:get, url).to_return(status: 200, body: 'x', headers: { 'ETag' => '"v2"' })

      expect(described_class.new(document).perform).to eq(:unchanged)

      expect(document.reload.metadata).to include('http_etag' => '"v2"')
    end
  end

  it 'persists the content fingerprint so the next sync of the same page is unchanged' do
    described_class.new(document).perform
    document.reload

    expect(document.content_fingerprint).to eq(Digest::SHA256.hexdigest('New content'))
    expect(document.sync_step).to be_nil
    expect(described_class.new(document).perform).to eq(:unchanged)
  end

  context 'when Firecrawl is not configured' do
    it 'fetches without any pre-check request' do
      described_class.new(document).perform

      expect(fetcher).to have_received(:fetch)
      expect(a_request(:get, url)).not_to have_been_made
      expect(document.reload.metadata).to include(validators)
    end
  end
end

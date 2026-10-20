require 'rails_helper'

RSpec.describe Captain::Websites::ImportPageJob do
  let(:assistant) { create(:captain_assistant) }
  let(:url) { 'https://www.example.com/pricing' }
  let(:source) do
    Captain::WebsiteSource.create!(assistant: assistant, url: 'https://www.example.com', status: 'ready', selected_urls: [url],
                                   pages: [{ 'url' => url }])
  end
  let(:document) do
    create(:captain_document, assistant: assistant, account: assistant.account, external_link: url, content: nil,
                              metadata: { 'website_source_id' => source.id, 'include_linked_pages' => false })
  end
  let(:content) { 'Plans start at ten euros per month and include unlimited subscribers and email support. ' * 3 }
  let(:fetcher) { instance_double(Captain::Websites::PageFetcher) }

  before do
    allow(Captain::Websites::PageFetcher).to receive(:new).and_return(fetcher)
    allow(fetcher).to receive(:fetch).and_return(
      Captain::Documents::SinglePageFetcher::Result.new(success: true, title: 'Pricing', content: content)
    )
  end

  it 'imports the page and remembers its text fingerprint' do
    described_class.perform_now(document.id)

    expect(document.reload).to have_attributes(content: content, sync_status: 'synced')
    expect(document.metadata['page_text_fingerprint']).to be_present
  end

  it 'removes a first import with too little text and excludes the page in the picker' do
    allow(fetcher).to receive(:fetch).and_return(
      Captain::Documents::SinglePageFetcher::Result.new(success: true, title: 'Thanks', content: 'Thanks for subscribing!')
    )
    described_class.perform_now(document.id)

    expect(Captain::Document.exists?(document.id)).to be(false)
    expect(source.reload.selected_urls).to eq([])
    expect(source.pages.first).to include('bucket' => 'excluded', 'reason' => 'thin')
  end

  it 'removes a first import whose page no longer exists' do
    allow(fetcher).to receive(:fetch).and_return(Captain::Documents::SinglePageFetcher::Result.new(success: false, error_code: 'not_found'))
    described_class.perform_now(document.id)

    expect(Captain::Document.exists?(document.id)).to be(false)
    expect(source.reload.pages.first).to include('bucket' => 'excluded', 'reason' => 'not_found')
  end

  it 'removes a first import whose text another enabled page already holds' do
    create(:captain_document, assistant: assistant, account: assistant.account, external_link: 'https://www.example.com/plans',
                              metadata: { 'page_text_fingerprint' => Digest::SHA256.hexdigest(content.gsub(/\s+/, ' ').strip) })
    described_class.perform_now(document.id)

    expect(source.reload.pages.first).to include('reason' => 'duplicate')
  end

  it 'keeps an imported page as failed when a later sync finds too little text' do
    document.update!(content: content, last_synced_at: 1.day.ago)
    allow(fetcher).to receive(:fetch).and_return(
      Captain::Documents::SinglePageFetcher::Result.new(success: true, title: 'Thanks', content: 'Thanks for subscribing!')
    )
    described_class.perform_now(document.id)

    expect(document.reload).to have_attributes(sync_status: 'failed', last_sync_error_code: 'thin_content', content: content)
  end
end

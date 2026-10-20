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

  it 'skips pages with too little text' do
    allow(fetcher).to receive(:fetch).and_return(
      Captain::Documents::SinglePageFetcher::Result.new(success: true, title: 'Thanks', content: 'Thanks for subscribing!')
    )
    described_class.perform_now(document.id)

    expect(document.reload).to have_attributes(sync_status: 'failed', last_sync_error_code: 'thin_content', content: nil)
  end

  it 'skips pages whose text another enabled page already holds' do
    create(:captain_document, assistant: assistant, account: assistant.account, external_link: 'https://www.example.com/plans',
                              metadata: { 'page_text_fingerprint' => Digest::SHA256.hexdigest(content.gsub(/\s+/, ' ').strip) })
    described_class.perform_now(document.id)

    expect(document.reload).to have_attributes(sync_status: 'failed', last_sync_error_code: 'duplicate_content')
  end
end

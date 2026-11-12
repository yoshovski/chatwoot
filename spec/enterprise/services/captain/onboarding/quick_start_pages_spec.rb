require 'rails_helper'

RSpec.describe Captain::Onboarding::QuickStartPages do
  let(:assistant) { create(:captain_assistant) }
  let(:selected_url) { 'https://www.example.com/shipping' }
  let(:source) do
    Captain::WebsiteSource.create!(assistant: assistant, url: 'https://www.example.com', status: 'ready', selected_urls: [selected_url],
                                   pages: [{ 'url' => selected_url }])
  end
  let!(:quick_unselected) do
    create(:captain_document, assistant: assistant, account: assistant.account, external_link: 'https://www.example.com/about',
                              metadata: { 'website_source_id' => source.id, 'quick_start' => true })
  end
  let!(:selected) do
    create(:captain_document, assistant: assistant, account: assistant.account, external_link: selected_url,
                              metadata: { 'website_source_id' => source.id })
  end

  it 'keeps quick-start pages while a selected page waits for its first import' do
    described_class.new(source).retire_unselected

    expect(Captain::Document.exists?(quick_unselected.id)).to be(true)
  end

  it 'removes unselected quick-start pages once the selected pages are imported' do
    selected.update!(last_sync_attempted_at: Time.current)

    described_class.new(source).retire_unselected

    expect(Captain::Document.exists?(quick_unselected.id)).to be(false)
    expect(Captain::Document.exists?(selected.id)).to be(true)
  end

  it 'replaces a selected quick-start page through the normal import' do
    selected.update!(metadata: selected.metadata.merge('quick_start' => true))
    fetcher = instance_double(Captain::Websites::PageFetcher)
    allow(Captain::Websites::PageFetcher).to receive(:new).and_return(fetcher)
    allow(fetcher).to receive(:fetch).and_return(
      Captain::Documents::SinglePageFetcher::Result.new(success: true, title: 'Shipping', content: 'Orders ship within two working days. ' * 10)
    )

    Captain::Websites::ImportPageJob.perform_now(selected.id)

    expect(selected.reload.metadata).not_to have_key('quick_start')
    expect(selected.content).to include('two working days')
    expect(Captain::Document.exists?(quick_unselected.id)).to be(false)
  end
end

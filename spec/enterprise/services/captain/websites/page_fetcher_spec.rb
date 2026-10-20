require 'rails_helper'

RSpec.describe Captain::Websites::PageFetcher do
  let(:assistant) { create(:captain_assistant) }
  let(:url) { 'https://support.example.com/hc/en-us/articles/7-Refunds' }
  let(:source) do
    Captain::WebsiteSource.create!(assistant: assistant, url: 'https://support.example.com', status: 'ready',
                                   pages: [{ 'url' => url, 'help_center_article_id' => 7 }])
  end
  let(:article_url) { 'https://support.example.com/api/v2/help_center/articles/7.json' }

  before do
    allow(Resolv).to receive(:getaddresses).and_call_original
    allow(Resolv).to receive(:getaddresses).with('support.example.com').and_return(['93.184.216.34'])
    stub_request(:get, 'https://support.example.com/robots.txt').to_return(status: 404)
  end

  it 'imports help-centre articles from the API body' do
    stub_request(:get, article_url).to_return(
      body: { article: { title: 'Refunds', body: '<h2>Refunds</h2><p>Refunds are issued within 14 days of a request.</p>' } }.to_json
    )
    result = described_class.new(source).fetch(url)

    expect(result).to have_attributes(success: true, title: 'Refunds')
    expect(result.content).to include('Refunds are issued within 14 days')
  end

  it 'falls back to the article page when the API refuses' do
    stub_request(:get, article_url).to_return(status: 403)
    stub_request(:get, url).to_return(body: '<html><head><title>Refunds</title></head><body><main><p>Refund policy text.</p></main></body></html>',
                                      headers: { 'Content-Type' => 'text/html' })
    result = described_class.new(source).fetch(url)

    expect(result).to have_attributes(success: true)
    expect(result.content).to include('Refund policy text.')
  end
end

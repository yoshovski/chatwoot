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

  context 'when llms.txt lists a markdown copy' do
    let(:url) { 'https://support.example.com/reference/create-an-order' }
    let(:source) do
      Captain::WebsiteSource.create!(assistant: assistant, url: 'https://support.example.com', status: 'ready',
                                     pages: [{ 'url' => url, 'markdown_url' => "#{url}.md" }])
    end
    let(:spec) do
      { openapi: '3.1.0', servers: [{ url: 'https://api.example.com/3.1/' }],
        paths: { '/orders': { post: { summary: 'Create an order', requestBody: { content: { 'application/json': { schema: {
          type: 'object', required: ['customerId'], properties: { customerId: { type: 'integer', description: 'Customer identifier' } }
        } } } } } } } }
    end

    it 'imports the markdown copy with API definitions as tables' do
      body = "---\nupdatedAt: 2026-05-27\n---\n\n# Create an order\n\nCreates an order.\n\n# OpenAPI definition\n\n```json\n#{spec.to_json}\n```\n"
      stub_request(:get, "#{url}.md").to_return(body: body, headers: { 'Content-Type' => 'text/markdown' })
      result = described_class.new(source).fetch(url)

      expect(result).to have_attributes(success: true, title: 'Create an order')
      expect(result.content).to include('Endpoint: `POST https://api.example.com/3.1/orders`', '| customerId | integer | yes | Customer identifier |')
      expect(result.content).not_to include('updatedAt', 'OpenAPI definition', '"openapi"')
    end

    it 'falls back to the page when the copy is missing' do
      stub_request(:get, "#{url}.md").to_return(status: 404)
      stub_request(:get, url).to_return(body: '<html><head><title>Orders</title></head><body><main><p>Order reference.</p></main></body></html>',
                                        headers: { 'Content-Type' => 'text/html' })

      expect(described_class.new(source).fetch(url).content).to include('Order reference.')
    end
  end
end

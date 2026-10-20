require 'rails_helper'

RSpec.describe Captain::Websites::DiscoveryService do
  let(:assistant) { create(:captain_assistant) }
  let(:source) { Captain::WebsiteSource.create!(assistant: assistant, url: 'https://www.example.com') }
  let(:prose) { 'Our platform helps publishers sell subscriptions and manage billing for every customer. ' * 12 }
  let(:html) do
    lambda do |title, body = "#{title}. #{prose}", links: []|
      anchors = links.map { |link| "<a href=\"#{link}\">#{link}</a>" }.join
      "<html lang=\"en\"><head><title>#{title}</title></head><body><nav>#{anchors}</nav><main><p>#{body}</p></main></body></html>"
    end
  end
  let(:sitemap) do
    <<~XML
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        <url><loc>https://www.example.com/pricing</loc></url>
        <url><loc>https://www.example.com/de/preise</loc></url>
        <url><loc>https://www.example.com/private/report</loc></url>
        <url><loc>https://www.example.com/tag/news</loc></url>
      </urlset>
    XML
  end

  before do
    allow(Resolv).to receive(:getaddresses).and_call_original
    %w[www.example.com support.example.com api.example.com].each do |host|
      allow(Resolv).to receive(:getaddresses).with(host).and_return(['93.184.216.34'])
    end
    stub_request(:get, %r{\Ahttps://[a-z.]+/(robots\.txt|sitemap(_index)?\.xml)\z}).to_return(status: 404)
    stub_request(:get, 'https://www.example.com/robots.txt')
      .to_return(body: "User-agent: *\nDisallow: /private\nSitemap: https://www.example.com/sitemap.xml\n")
    stub_request(:get, 'https://www.example.com/sitemap.xml').to_return(body: sitemap)
    stub_request(:get, 'https://www.example.com')
      .to_return(body: html.call('Home', links: %w[/pricing https://api.example.com/v1 https://support.example.com/hc/en-us/articles/7-Old]),
                 headers: { 'Content-Type' => 'text/html' })
    stub_request(:get, 'https://www.example.com/pricing').to_return(body: html.call('Pricing'), headers: { 'Content-Type' => 'text/html' })
    stub_request(:get, 'https://www.example.com/tag/news')
      .to_return(body: html.call('News', 'Short list.'), headers: { 'Content-Type' => 'text/html' })
    stub_request(:get, 'https://support.example.com/hc/en-us/articles/7-Old').to_return(status: 404)
    stub_request(:get, 'https://support.example.com/api/v2/help_center/locales.json')
      .to_return(body: { locales: %w[en-us], default_locale: 'en-us' }.to_json)
    stub_request(:get, 'https://support.example.com/api/v2/help_center/en-us/sections.json?per_page=100')
      .to_return(body: { sections: [{ id: 5, name: 'Payments' }], next_page: nil }.to_json)
    stub_request(:get, 'https://support.example.com/api/v2/help_center/en-us/articles.json?per_page=100')
      .to_return(body: { articles: [{ id: 7, html_url: 'https://support.example.com/hc/en-us/articles/7-Refunds', title: 'Refunds',
                                      section_id: 5, body: "<p>#{prose}</p>", updated_at: '2026-10-01T10:00:00Z' }],
                         next_page: nil }.to_json)
  end

  def page(url) = source.reload.pages.find { |item| item['url'] == url }

  it 'discovers, measures and sorts pages, then asks for section labels' do
    expect { described_class.new(source).perform }
      .to have_enqueued_job(Captain::Websites::ClassifySectionsJob).with(source.id, kind_of(String))

    expect(source.reload).to have_attributes(status: 'ready')
    expect(source.discovery_stats).to include('classification' => 'pending', 'limited' => false, 'help_center_articles' => 1)
    expect(page('https://www.example.com')).to include('bucket' => 'recommended', 'title' => 'Home', 'lang' => 'en')
    expect(page('https://www.example.com/pricing')).to include('bucket' => 'recommended')
    expect(page('https://www.example.com/pricing')['words']).to be > 60
    expect(page('https://www.example.com/de/preise')).to include('bucket' => 'excluded', 'reason' => 'other_language')
    expect(page('https://www.example.com/private/report')).to include('blocked_reason' => 'robots_disallowed')
    expect(page('https://www.example.com/tag/news')).to include('bucket' => 'excluded', 'reason' => 'listing')
    expect(page('https://api.example.com/v1')).to include('bucket' => 'excluded', 'reason' => 'technical_host')
    expect(page('https://support.example.com/hc/en-us/articles/7-Refunds'))
      .to include('bucket' => 'recommended', 'section' => 'support.example.com/Payments', 'title' => 'Refunds')
  end

  it 'never fetches technical hosts or other-language copies' do
    described_class.new(source).perform

    expect(a_request(:get, %r{\Ahttps://api\.example\.com})).not_to have_been_made
    expect(a_request(:get, 'https://www.example.com/de/preise')).not_to have_been_made
  end

  it 'leaves pages unchecked, not robots-blocked, past the origin limit' do
    stub_const('Captain::Websites::OriginRobots::MAX_ORIGINS', 1)
    described_class.new(source).perform

    expect(source.reload.discovery_stats['limits']).to include('origins')
    expect(page('https://support.example.com/hc/en-us/articles/7-Old')).not_to have_key('blocked_reason')
  end
end

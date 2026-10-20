require 'rails_helper'

RSpec.describe Captain::Websites::PageBuckets do
  let(:assistant) { create(:captain_assistant) }
  let(:source) do
    Captain::WebsiteSource.create!(assistant: assistant, url: 'https://www.example.com', status: 'ready')
  end
  let(:pages) do
    [
      { 'url' => 'https://www.example.com', 'lang' => 'en', 'words' => 400, 'fingerprint' => 'home' },
      { 'url' => 'https://www.example.com/pricing', 'words' => 300, 'fingerprint' => 'pricing' },
      { 'url' => 'https://www.example.com/pricing-copy', 'words' => 300, 'fingerprint' => 'pricing' },
      { 'url' => 'https://www.example.com/de/preise', 'words' => 300 },
      { 'url' => 'https://www.example.com/thanks', 'words' => 12 },
      { 'url' => 'https://www.example.com/landing', 'words' => 200, 'canonical' => 'https://www.example.com/pricing' },
      { 'url' => 'https://blog.example.com/launch', 'words' => 900 },
      { 'url' => 'https://support.example.com/hc/en-us/articles/1-Setup', 'section' => 'support.example.com/Setup',
        'discovered_from' => 'help_center', 'words' => 250 },
      { 'url' => 'https://api.example.com/v1' },
      { 'url' => 'https://www.example.com/private', 'blocked_reason' => 'robots_disallowed' }
    ]
  end

  it 'sorts pages with URL and content rules when no section labels exist' do
    result = described_class.new(source).perform(pages).to_h { |page| [page['url'], page.values_at('bucket', 'reason')] }

    expect(result).to eq(
      'https://www.example.com' => ['recommended', nil],
      'https://www.example.com/pricing' => ['recommended', nil],
      'https://www.example.com/pricing-copy' => %w[excluded duplicate],
      'https://www.example.com/de/preise' => %w[excluded other_language],
      'https://www.example.com/thanks' => %w[excluded thin],
      'https://www.example.com/landing' => %w[excluded duplicate],
      'https://blog.example.com/launch' => ['maybe', nil],
      'https://support.example.com/hc/en-us/articles/1-Setup' => ['recommended', nil],
      'https://api.example.com/v1' => %w[excluded technical_host],
      'https://www.example.com/private' => %w[excluded robots_disallowed]
    )
  end

  it 'keeps one copy of the same text, preferring the canonical HTTPS page' do
    copies = [
      { 'url' => 'http://blog.example.com/a', 'fingerprint' => 'post', 'canonical' => 'https://blog.example.com/a', 'words' => 900 },
      { 'url' => 'https://blog.example.com/a', 'fingerprint' => 'post', 'words' => 900 },
      { 'url' => 'https://www.example.com/a', 'fingerprint' => 'post', 'canonical' => 'https://blog.example.com/a', 'words' => 900 }
    ]
    result = described_class.new(source).perform(copies)

    expect(result.map { |page| page['reason'] }).to eq(['duplicate', nil, 'duplicate'])
  end

  it 'follows section labels over the host defaults' do
    source.update!(discovery_stats: { 'sections' => {
                     'blog.example.com/launch' => { 'label' => 'support', 'recommended' => true, 'reason' => 'Guides' },
                     'example.com/pricing' => { 'label' => 'not_useful', 'recommended' => false, 'reason' => 'Old' }
                   } })
    result = described_class.new(source).perform(pages).to_h { |page| [page['url'], page.values_at('bucket', 'reason')] }

    expect(result.values_at('https://blog.example.com/launch', 'https://www.example.com/pricing'))
      .to eq([['recommended', nil], %w[excluded not_useful]])
  end
end

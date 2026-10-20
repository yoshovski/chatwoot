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

  def bucket_of(result, url) = result.find { |page| page['url'] == url }.values_at('bucket', 'reason')

  it 'sorts pages with URL and content rules when no section labels exist' do
    result = described_class.new(source).perform(pages)

    expect(bucket_of(result, 'https://www.example.com')).to eq(['recommended', nil])
    expect(bucket_of(result, 'https://www.example.com/pricing')).to eq(['recommended', nil])
    expect(bucket_of(result, 'https://www.example.com/pricing-copy')).to eq(%w[excluded duplicate])
    expect(bucket_of(result, 'https://www.example.com/landing')).to eq(%w[excluded duplicate])
    expect(bucket_of(result, 'https://www.example.com/de/preise')).to eq(%w[excluded other_language])
    expect(bucket_of(result, 'https://www.example.com/thanks')).to eq(%w[excluded thin])
    expect(bucket_of(result, 'https://blog.example.com/launch')).to eq(['maybe', nil])
    expect(bucket_of(result, 'https://support.example.com/hc/en-us/articles/1-Setup')).to eq(['recommended', nil])
    expect(bucket_of(result, 'https://api.example.com/v1')).to eq(%w[excluded technical_host])
    expect(bucket_of(result, 'https://www.example.com/private')).to eq(%w[excluded robots_disallowed])
  end

  it 'follows section labels over the host defaults' do
    source.update!(discovery_stats: { 'sections' => {
                     'blog.example.com/launch' => { 'label' => 'support', 'recommended' => true, 'reason' => 'Guides' },
                     'example.com/pricing' => { 'label' => 'not_useful', 'recommended' => false, 'reason' => 'Old' }
                   } })
    result = described_class.new(source).perform(pages)

    expect(bucket_of(result, 'https://blog.example.com/launch')).to eq(['recommended', nil])
    expect(bucket_of(result, 'https://www.example.com/pricing')).to eq(%w[excluded not_useful])
  end
end

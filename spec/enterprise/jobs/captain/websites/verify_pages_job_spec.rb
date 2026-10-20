require 'rails_helper'

RSpec.describe Captain::Websites::VerifyPagesJob do
  let(:assistant) { create(:captain_assistant) }
  let(:source) do
    Captain::WebsiteSource.create!(
      assistant: assistant, url: 'https://www.example.com', status: 'ready',
      discovery_stats: { 'run' => 'run-1', 'verification' => 'pending' },
      pages: %w[old account pricing].map { |slug| { 'url' => "https://www.example.com/#{slug}-page", 'bucket' => 'recommended' } } +
             [{ 'url' => 'https://www.example.com', 'words' => 300, 'bucket' => 'recommended' }]
    )
  end

  before do
    allow(Resolv).to receive(:getaddresses).and_call_original
    allow(Resolv).to receive(:getaddresses).with('www.example.com').and_return(['93.184.216.34'])
    stub_request(:get, 'https://www.example.com/robots.txt').to_return(status: 404)
    stub_request(:get, 'https://www.example.com/old-page').to_return(status: 404)
    stub_request(:get, 'https://www.example.com/account-page').to_return(status: 401)
    stub_request(:get, 'https://www.example.com/pricing-page').to_return(status: 200, body: 'ok')
  end

  it 'excludes missing and sign-in pages and marks the rest as checked' do
    described_class.perform_now(source.id, 'run-1')
    pages = source.reload.pages.index_by { |page| page['url'] }

    expect(source.discovery_stats).to include('verification' => 'done', 'verified_pages' => 3)
    expect(pages['https://www.example.com/old-page']).to include('bucket' => 'excluded', 'reason' => 'not_found')
    expect(pages['https://www.example.com/account-page']).to include('bucket' => 'excluded', 'reason' => 'login')
    expect(pages['https://www.example.com/pricing-page']).to include('bucket' => 'recommended', 'checked' => true)
    expect(a_request(:get, 'https://www.example.com')).not_to have_been_made
  end

  it 'ignores an older discovery run' do
    described_class.perform_now(source.id, 'run-0')

    expect(a_request(:get, %r{example\.com/.+-page})).not_to have_been_made
  end
end

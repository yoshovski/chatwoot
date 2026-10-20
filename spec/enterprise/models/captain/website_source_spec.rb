require 'rails_helper'

RSpec.describe Captain::WebsiteSource do
  let(:assistant) { create(:captain_assistant) }
  let(:source) do
    described_class.create!(
      assistant: assistant, url: 'https://www.example.com', status: 'ready',
      discovery_stats: {
        'boilerplate' => { 'example.com' => ['hash'] },
        'sections' => { 'example.com/help' => { 'label' => 'support', 'recommended' => true, 'reason' => 'Help' } },
        'page_labels' => { 'https://www.example.com/careers' => { 'label' => 'careers', 'recommended' => false, 'reason' => 'Jobs' } }
      },
      pages: [{ 'url' => 'https://www.example.com/careers', 'section' => 'example.com/careers', 'bucket' => 'maybe', 'words' => 200 }]
    )
  end

  it 'shows page labels as the labels of their one-page sections and keeps server-only stats out' do
    expect(source.client_stats).to eq(
      'sections' => {
        'example.com/help' => { 'label' => 'support', 'recommended' => true, 'reason' => 'Help' },
        'example.com/careers' => { 'label' => 'careers', 'recommended' => false, 'reason' => 'Jobs' }
      }
    )
  end

  it 'leaves pages that can never become knowledge out of the picker and counts them' do
    source.update!(pages: source.pages + [{ 'url' => 'https://www.example.com/gone', 'bucket' => 'excluded', 'reason' => 'not_found' },
                                          { 'url' => 'https://www.example.com/empty', 'bucket' => 'excluded', 'reason' => 'thin' },
                                          { 'url' => 'https://www.example.com/tag/a', 'bucket' => 'excluded', 'reason' => 'listing' }])

    payload = source.client_payload

    expect(payload['pages'].pluck('url')).to eq(%w[https://www.example.com/careers https://www.example.com/tag/a])
    expect(payload['hidden_pages']).to eq(2)
  end
end

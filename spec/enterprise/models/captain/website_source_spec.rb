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
end

require 'rails_helper'

RSpec.describe Captain::Websites::SelectionService do
  let(:assistant) { create(:captain_assistant) }
  let(:source) do
    Captain::WebsiteSource.create!(assistant: assistant, url: 'https://www.example.com', status: 'discovering',
                                   pages: [{ 'url' => 'https://www.example.com/pricing' },
                                           { 'url' => 'https://www.example.com/private', 'blocked_reason' => 'robots_disallowed' }])
  end

  it 'saves a selection while discovery is still running' do
    described_class.new(source).perform(['https://www.example.com/pricing'])

    expect(source.reload.selected_urls).to eq(['https://www.example.com/pricing'])
    expect(assistant.documents.pluck(:external_link)).to eq(['https://www.example.com/pricing'])
  end

  it 'rejects blocked pages' do
    expect { described_class.new(source).perform(['https://www.example.com/private']) }
      .to raise_error(described_class::InvalidSelection)
  end
end

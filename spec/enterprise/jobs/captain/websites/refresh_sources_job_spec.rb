require 'rails_helper'

RSpec.describe Captain::Websites::RefreshSourcesJob do
  let(:assistant) { create(:captain_assistant) }

  before { allow(Resolv).to receive(:getaddresses).and_return(['93.184.216.34']) }

  def website(url, **attributes)
    Captain::WebsiteSource.create!(assistant: assistant, url: url, status: 'ready', discovered_at: 8.days.ago,
                                   selected_urls: ["#{url}/pricing"], **attributes)
  end

  it 'refreshes week-old websites that add new pages automatically' do
    due = website('https://due.example.com')
    website('https://recent.example.com', discovered_at: 1.day.ago)
    website('https://manual.example.com', auto_add_pages: false)
    website('https://unchosen.example.com', selected_urls: [])

    expect { described_class.perform_now }.to have_enqueued_job(Captain::Websites::DiscoverJob).with(due.id, 'refresh').exactly(:once)
  end
end

require 'rails_helper'

RSpec.describe Widget::WebsiteActivity do
  let(:contact_inbox) { create(:contact_inbox) }
  let(:browser) { { 'browser_name' => 'Chrome' } }

  def record(url: 'https://shop.example.com/plans?utm_campaign=spring#top', **visit)
    described_class.new(contact_inbox).record!(url: url, title: 'Plans', browser: browser, browser_language: 'en', visit: visit)
    contact_inbox.reload.website_activity
  end

  it 'stores the page without query or fragment and starts the first visit' do
    freeze_time do
      activity = record(arrival: { referrer_host: 'www.google.com', utm_campaign: 'spring' })

      expect(activity['current_page']['url']).to eq('https://shop.example.com/plans')
      expect(activity['recent_pages'].map { |page| page['url'] }).to eq(['https://shop.example.com/plans'])
      expect(activity).to include('first_seen_at' => Time.current.iso8601(6), 'visit_count' => 1)
      expect(activity['arrival']).to eq('referrer_host' => 'www.google.com', 'utm_campaign' => 'spring', 'landed_at' => Time.current.iso8601(6))
    end
  end

  it 'keeps first_seen_at and the visit within 30 minutes' do
    first = travel_to(1.hour.ago) { record(arrival: { utm_source: 'newsletter' }) }
    travel_to(25.minutes.ago) { record(url: 'https://shop.example.com/a') }
    activity = travel_to(10.minutes.ago) { record(url: 'https://shop.example.com/b', arrival: { utm_source: 'ads' }) }

    expect(activity['first_seen_at']).to eq(first['first_seen_at'])
    expect(activity['visit_count']).to eq(2)
    expect(activity['recent_pages'].size).to eq(3)
  end

  it 'starts a new visit with a new arrival after 30 minutes without a page view' do
    travel_to(2.hours.ago) { record(arrival: { utm_campaign: 'old' }) }
    activity = record(arrival: { referrer_host: 'bing.com' })

    expect(activity['visit_count']).to eq(2)
    expect(activity['arrival'].except('landed_at')).to eq('referrer_host' => 'bing.com')
  end

  it 'keeps the arrival of a visit and fills it only when the visit has no source yet' do
    record
    activity = record(arrival: { utm_campaign: 'spring' })
    expect(activity['arrival'].except('landed_at')).to eq('utm_campaign' => 'spring')

    activity = record(arrival: { utm_campaign: 'other' })
    expect(activity['arrival'].except('landed_at')).to eq('utm_campaign' => 'spring')
  end

  it 'cuts UTM values to 100 characters and drops invalid referrer hosts' do
    activity = record(arrival: { utm_source: 'a' * 150, utm_medium: " cpc\n", referrer_host: 'evil.com/path?x=1' })

    expect(activity['arrival']['utm_source']).to eq('a' * 100)
    expect(activity['arrival']['utm_medium']).to eq('cpc')
    expect(activity['arrival']).not_to have_key('referrer_host')
  end

  it 'stores a valid browser time zone and ignores an unknown one' do
    expect(record(timezone: 'Europe/Madrid')['timezone']).to eq('Europe/Madrid')
    expect(record(timezone: 'Mars/Olympus')['timezone']).to eq('Europe/Madrid')
  end

  it 'counts an existing activity from before visits were tracked as the first visit' do
    contact_inbox.update!(website_activity: { 'current_page' => { 'url' => 'https://shop.example.com/', 'last_seen_at' => Time.current.iso8601(6) },
                                              'recent_pages' => [{ 'url' => 'https://shop.example.com/', 'visited_at' => 1.day.ago.iso8601(6) }] })
    activity = record

    expect(activity['visit_count']).to eq(1)
    expect(activity['first_seen_at']).to eq(contact_inbox.website_activity.dig('recent_pages', 0, 'visited_at'))
  end
end

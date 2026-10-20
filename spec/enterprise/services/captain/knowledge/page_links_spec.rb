require 'rails_helper'

RSpec.describe Captain::Knowledge::PageLinks do
  let(:links) { described_class.new('https://www.example.com/help/refunds') }

  it 'resolves relative targets and removes tracking parameters and fragments' do
    expect(links.resolve('/pricing?utm_source=x&hsCtaAttrib=1&plan=pro#faq')).to eq('https://www.example.com/pricing?plan=pro')
    expect(links.resolve('<https://shop.example.com/cart> "Cart"')).to eq('https://shop.example.com/cart')
    expect(links.resolve('mailto:help@example.com')).to eq('mailto:help@example.com')
  end

  it 'ignores in-page anchors, scripts and the page itself' do
    expect([links.resolve('#top'), links.resolve('javascript:void(0)'), links.resolve('/help/refunds/')]).to all(be_nil)
  end

  it 'collects each target once, preferring https, up to the limit' do
    links.collect('Sign up', 'http://app.example.com/register')
    links.collect('Sign up', 'https://app.example.com/register')
    25.times { |index| links.collect("Page #{index}", "/page-#{index}") }

    expect(links.section.lines.size).to eq(2 + described_class::MAX_LINKS)
    expect(links.section).to include('- Sign up: https://app.example.com/register')
    expect(links.section).not_to include('http://app')
  end
end

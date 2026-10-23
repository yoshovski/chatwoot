require 'rails_helper'

RSpec.describe Captain::Assistant::ResponseParts do
  let(:response_parts) { described_class.new([{ 'text' => 'Call the transfer endpoint.', 'citation_indexes' => [1, 2] }]) }
  let(:citation_urls) { { 1 => 'https://docs.example.com/transfer', 2 => 'https://docs.example.com/billing' } }
  let(:citation_titles) { { 1 => 'Transfer purchase', 2 => '' } }

  it 'lists cited pages by title, naming untitled ones after their path' do
    expect(response_parts.sources(citation_urls: citation_urls, citation_titles: citation_titles)).to eq(
      [{ 'title' => 'Transfer purchase', 'url' => 'https://docs.example.com/transfer' },
       { 'title' => 'Billing', 'url' => 'https://docs.example.com/billing' }]
    )
  end

  it 'writes sources as markdown links, plain title and url lines, or leaves them to the widget' do
    content = ->(format) { response_parts.customer_message_content(citation_urls: citation_urls, citation_titles: citation_titles, sources_format: format) }

    expect(content.call(:markdown)).to eq(
      "Call the transfer endpoint.\n\n→ [Transfer purchase](https://docs.example.com/transfer)\n→ [Billing](https://docs.example.com/billing)"
    )
    expect(content.call(:plain)).to eq(
      "Call the transfer endpoint.\n\n→ Transfer purchase: https://docs.example.com/transfer\n→ Billing: https://docs.example.com/billing"
    )
    expect(content.call(:structured)).to eq('Call the transfer endpoint.')
  end

  it 'picks the source format from the conversation channel' do
    widget = create(:conversation, inbox: create(:inbox, channel: create(:channel_widget)))
    email = create(:conversation, inbox: create(:inbox, channel: create(:channel_email)))
    sms = create(:conversation, inbox: create(:inbox, channel: create(:channel_sms)))

    expect([nil, widget, email, sms].map { |conversation| described_class.sources_format(conversation) })
      .to eq(%i[structured structured markdown plain])
  end
end

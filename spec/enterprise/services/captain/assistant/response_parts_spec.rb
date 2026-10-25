require 'rails_helper'

RSpec.describe Captain::Assistant::ResponseParts do
  let(:response_parts) { described_class.new([{ 'text' => 'Call the transfer endpoint.', 'citation_indexes' => [1, 2] }]) }
  let(:citation_urls) { { 1 => 'https://docs.example.com/transfer', 2 => 'https://docs.example.com/billing' } }
  let(:citation_titles) { { 1 => 'Transfer purchase', 2 => '' } }

  it 'removes bare source indexes from text while preserving structured citations and markdown links' do
    parts = described_class.from_response(
      'response_parts' => [
        {
          'text' => 'A Merchant of Record handles taxes [11, 21]. Read the [guide](https://docs.example.com/merchant).',
          'citation_indexes' => [11, 21]
        }
      ]
    )

    expect(parts.plain_text).to eq('A Merchant of Record handles taxes. Read the [guide](https://docs.example.com/merchant).')
    expect(parts.to_a.first['citation_indexes']).to eq([11, 21])
  end

  it 'lists cited pages by title, naming untitled ones after their path' do
    expect(response_parts.sources(citation_urls: citation_urls, citation_titles: citation_titles)).to eq(
      [{ 'title' => 'Transfer purchase', 'url' => 'https://docs.example.com/transfer' },
       { 'title' => 'Billing', 'url' => 'https://docs.example.com/billing' }]
    )

    linked_answer = described_class.new([{ 'text' => 'Use the [transfer guide](https://docs.example.com/transfer).', 'citation_indexes' => [1] }])
    expect(linked_answer.sources(citation_urls: citation_urls, citation_titles: citation_titles)).to eq(
      [{ 'title' => 'Transfer purchase', 'url' => 'https://docs.example.com/transfer' }]
    )
    expect(linked_answer.customer_message_content(citation_urls: citation_urls, sources_format: :markdown)).to eq(linked_answer.plain_text)
  end

  it 'writes sources as markdown links, plain title and url lines, or leaves them to the widget' do
    content = lambda do |format|
      response_parts.customer_message_content(citation_urls: citation_urls, citation_titles: citation_titles, sources_format: format)
    end

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
    expect([nil, widget, email, sms].map { |conversation| described_class.sources_format(conversation, sources_card: false) })
      .to eq(%i[none none none none])
  end

  describe '#with_fallback_citation' do
    let(:answer) do
      'Clear the cache and cookies of your browser: open the settings, choose privacy, then clear browsing data ' \
        'and reload the page to watch again.'
    end
    let(:titles) { { 1 => 'Why and how to clear cache and cookies', 2 => 'Requesting a refund' } }

    def fallback(text, citation_indexes: [], citation_titles: titles)
      described_class.new([{ 'text' => text, 'citation_indexes' => citation_indexes }])
                     .with_fallback_citation(citation_titles: citation_titles).to_a.first['citation_indexes']
    end

    it 'cites the page whose title shares the most words with an uncited answer' do
      expect(fallback(answer)).to eq([1])
    end

    it 'leaves answers alone that already cite, are short, or match no title' do
      expect(fallback(answer, citation_indexes: [2])).to eq([2])
      expect(fallback('Clear the cache and cookies.')).to eq([])
      expect(fallback(answer, citation_titles: { 2 => 'Requesting a refund' })).to eq([])
    end

    it 'ignores words every title shares, such as the product name' do
      parts = described_class.new([{ 'text' => "#{answer} Cleeng support", 'citation_indexes' => [] }])
      cited = parts.with_fallback_citation(citation_titles: { 3 => 'Cleeng support | Cleeng' }, ignored_words: %w[Cleeng support])

      expect(cited.to_a.first['citation_indexes']).to eq([])
    end
  end
end

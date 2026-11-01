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

  it 'opens with the AI welcome of a first reply' do
    parts = described_class.from_response(
      { 'welcome' => 'Hi, thanks for reaching out!', 'response_parts' => [{ 'text' => 'Yes, you can.', 'citation_indexes' => [1] }] }
    )

    expect(parts.plain_text).to eq("Hi, thanks for reaching out!\n\nYes, you can.")
    expect(parts.to_a.first['citation_indexes']).to eq([])
  end

  describe 'a first part that repeats the AI welcome' do
    let(:welcome) { 'Hello and welcome! I can certainly help you with that.' }
    let(:steps) { { 'text' => "1. Open Settings in Lumen Notes.\n2. Choose Sync.", 'citation_indexes' => [2] } }

    def guarded(first_text, rest = [steps], first_citations: [])
      described_class.from_response(
        { 'welcome' => welcome, 'response_parts' => [{ 'text' => first_text, 'citation_indexes' => first_citations }, *rest] }
      ).log_welcome_guard
    end

    it 'drops an exact copy of the welcome and logs it' do
      allow(Rails.logger).to receive(:info)
      parts = guarded('Hello and welcome! I can certainly help you with that.')

      expect(parts.plain_text).to eq("#{welcome}\n\n#{steps['text']}")
      expect(parts.index_offset).to eq(0)
      expect(Rails.logger).to have_received(:info).with('[Captain][ReplyGuard] rule=duplicate_welcome action=dropped').once
    end

    it 'treats case, punctuation and emoji variants as the same welcome' do
      expect(guarded('hello AND welcome 👋 I can certainly help you with that').plain_text).to eq("#{welcome}\n\n#{steps['text']}")
    end

    it 'moves the citations of a dropped copy to the next part' do
      parts = guarded(welcome, first_citations: [1, 2])

      expect(parts.to_a.last['citation_indexes']).to eq([1, 2])
    end

    it 'strips the welcome from the start of the answer' do
      allow(Rails.logger).to receive(:info)
      parts = guarded("#{welcome} 😊 To sync your notes, open Settings.")

      expect(parts.to_a.pluck('text')).to eq([welcome, 'To sync your notes, open Settings.', steps['text']])
      expect(parts.index_offset).to eq(1)
      expect(Rails.logger).to have_received(:info).with('[Captain][ReplyGuard] rule=duplicate_welcome action=stripped').once
    end

    it 'strips a different greeting-only first sentence' do
      parts = guarded('Hi there! To sync your notes, open Settings.')

      expect(parts.to_a.pluck('text').first(2)).to eq([welcome, 'To sync your notes, open Settings.'])
    end

    it 'strips greetings in other languages' do
      parts = described_class.from_response(
        { 'welcome' => '¡Hola y bienvenido!',
          'response_parts' => [{ 'text' => '¡Hola! Abre Ajustes y elige Sincronizar.', 'citation_indexes' => [] }] }
      )

      expect(parts.to_a.pluck('text')).to eq(['¡Hola y bienvenido!', 'Abre Ajustes y elige Sincronizar.'])
    end

    it 'keeps a normal first sentence that starts with a greeting word' do
      parts = guarded('Hello World is our sample notebook.')

      expect(parts.to_a.pluck('text').first(2)).to eq([welcome, 'Hello World is our sample notebook.'])
      expect(parts.index_offset).to eq(1)
    end

    it 'keeps an answer whose first sentence only starts with the welcome words' do
      parts = described_class.from_response(
        { 'welcome' => 'Welcome!', 'response_parts' => [{ 'text' => 'Welcome emails go out within an hour.', 'citation_indexes' => [] }] }
      )

      expect(parts.plain_text).to eq("Welcome!\n\nWelcome emails go out within an hour.")
    end

    it 'keeps the original parts when only the welcome would remain' do
      allow(Rails.logger).to receive(:info)
      parts = guarded(welcome, [])

      expect(parts.to_a.pluck('text')).to eq([welcome, welcome])
      expect(Rails.logger).not_to have_received(:info).with(/ReplyGuard/)
    end

    it 'changes nothing without a welcome' do
      parts = described_class.from_response({ 'response_parts' => [{ 'text' => 'Hi there! Open Settings.', 'citation_indexes' => [] }] })

      expect(parts.plain_text).to eq('Hi there! Open Settings.')
      expect(parts.index_offset).to eq(0)
    end

    it 'logs only when asked, so a reply checked several times logs once' do
      allow(Rails.logger).to receive(:info)
      parts = described_class.from_response({ 'welcome' => welcome, 'response_parts' => [{ 'text' => welcome, 'citation_indexes' => [] }, steps] })

      expect(parts.welcome_guard).to eq('dropped')
      expect(Rails.logger).not_to have_received(:info).with(/ReplyGuard/)
    end
  end
end

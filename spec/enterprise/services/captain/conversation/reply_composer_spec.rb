# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Captain::Conversation::ReplyComposer do
  subject(:composer) do
    described_class.new(
      assistant: assistant,
      conversation: conversation,
      response: response,
      run_result: run_result
    )
  end

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:assistant) do
    create(:captain_assistant, account: account,
                               config: { 'suggested_replies' => true, 'max_suggested_replies' => 3, 'product_cards' => true,
                                         'image_allowlist' => ['https://cdn.shopify.com/'] })
  end
  let(:link) { { 'type' => 'link', 'text' => 'View', 'uri' => 'https://example-store.com' } }
  let(:tool_state) { {} }
  let(:run_result) { instance_double(Agents::RunResult, context: { state: tool_state }) }
  let(:response) do
    {
      'agent_name' => 'Store Bot',
      'response' => 'We ship within two days.',
      'response_parts' => [{ 'text' => 'We ship within two days.', 'citation_indexes' => [] }],
      'suggested_replies' => ['Track order', 'Return item']
    }
  end

  it 'returns the answer with suggestion buttons and writes nothing' do
    messages = composer.messages

    expect(messages.size).to eq(1)
    expect(messages.first).to include(content: 'We ship within two days.', content_type: 'input_select')
    expect(messages.first[:content_attributes][:items]).to eq(
      [{ 'title' => 'Track order', 'value' => 'Track order' }, { 'title' => 'Return item', 'value' => 'Return item' }]
    )
    expect(messages.first[:additional_attributes]).to eq(
      { :agent_name => 'Store Bot',
        Captain::Assistant::ResponseParts::MESSAGE_ATTRIBUTE_KEY => [{ 'text' => 'We ship within two days.', 'citation_indexes' => [] }] }
    )
    expect { composer.messages }.not_to(change { conversation.messages.count })
  end

  it 'marks suggestion buttons so a click sends the value' do
    expect(composer.messages.first[:content_attributes][:submit_value]).to be(true)
  end

  context 'with cited sources' do
    let(:assistant) do
      create(:captain_assistant, account: account,
                                 config: { 'suggested_replies' => true, 'max_suggested_replies' => 3, 'feature_citation' => true })
    end
    let(:response) do
      {
        'response_parts' => [{ 'text' => 'We ship within two days.', 'citation_indexes' => [1] }],
        'suggested_replies' => ['Track order']
      }
    end

    before do
      allow(assistant).to receive_messages(trusted_citation_urls: { 1 => 'https://example-store.com/shipping' },
                                           citation_titles: { 1 => 'Shipping policy' })
    end

    it 'gives widget messages the sources as an attribute, next to the buttons' do
      message = composer.messages.first

      expect(message[:content]).to eq('We ship within two days.')
      expect(message[:content_attributes]).to include(
        'captain_sources' => [{ 'title' => 'Shipping policy', 'url' => 'https://example-store.com/shipping' }],
        :items => [{ 'title' => 'Track order', 'value' => 'Track order' }]
      )
    end

    it 'writes the sources into the text on channels without the widget' do
      inbox.update!(channel: create(:channel_sms, account: account))

      expect(composer.messages.first[:content]).to eq("We ship within two days.\n\n→ Shipping policy: https://example-store.com/shipping")
    end
  end

  context 'with cited sources and Show sources off' do
    let(:screenshot) { '[Screenshot: Shipping settings screen](https://docs.example.com/shipping.png)' }
    let(:video) { '[Video](https://www.youtube.com/watch?v=abc123xyz)' }
    let(:tool_state) do
      { knowledge_screenshots: ['https://docs.example.com/shipping.png'],
        knowledge_media: { 1 => [video, screenshot], 2 => ['[Video](https://www.youtube.com/watch?v=unrelated123)'] } }
    end
    let(:answer) { "We ship within two days.\n\n1. Read the [shipping settings](https://example-store.com/shipping)." }
    let(:response) do
      {
        'response_parts' => [{ 'text' => answer, 'citation_indexes' => [1] }],
        'suggested_replies' => ['Track order']
      }
    end

    before do
      allow(assistant).to receive_messages(trusted_citation_urls: { 1 => 'https://example-store.com/shipping' },
                                           citation_titles: { 1 => 'Shipping policy' })
    end

    it 'omits the source footer while retaining inline links, cited media and buttons' do
      message = composer.messages.first

      expect(message[:content]).to eq("#{answer}\n\n#{video}\n\n#{screenshot}")
      expect(message[:content_type]).to eq('input_select')
      expect(message[:content_attributes]).not_to have_key('captain_sources')
    end
  end

  context 'when the model cites nothing for an answer taken from one page' do
    let(:answer) do
      'To register an in-app purchase, call the purchase registration endpoint with the Apple StoreKit 2 transaction ' \
        'after the purchase completes in the app.'
    end
    let(:response) { { 'response_parts' => [{ 'text' => answer, 'citation_indexes' => [] }] } }

    before do
      allow(assistant).to receive_messages(
        product_name: 'Cleeng',
        trusted_citation_urls: { 1 => 'https://example.com/docs/storekit-2', 2 => 'https://example.com/pricing' },
        citation_titles: { 1 => 'Apple in-app purchase (StoreKit 2) | Cleeng', 2 => 'Pricing | Cleeng' }
      )
    end

    it 'keeps inferred references out of the reply when source cards are off' do
      expect(composer.messages.first[:content]).to eq(answer)
    end
  end

  context 'with labelled suggestions' do
    let(:response) do
      {
        'response' => 'Your order is paid.',
        'response_parts' => [{ 'text' => 'Your order is paid.', 'citation_indexes' => [] }],
        'suggested_replies' => [
          { 'label' => 'Shipping time', 'message' => 'When will order 1001 ship?' },
          { 'label' => 'A label that is far too long for a button exceeding fifty characters', 'message' => 'Dropped' },
          { 'label' => 'Order items', 'message' => '' }
        ]
      }
    end

    it 'shortens long labels and keeps the full question instead of dropping the button' do
      expect(composer.messages.first[:content_attributes][:items]).to eq(
        [{ 'title' => 'Shipping time', 'value' => 'When will order 1001 ship?' },
         { 'title' => 'A label that is far too long for a button...', 'value' => 'Dropped' }, { 'title' => 'Order items', 'value' => 'Order items' }]
      )
    end
  end

  context 'when the run looked up an order' do
    let(:tool_state) do
      { Captain::Assistant::ORDER_STATE_KEY => { 'order_number' => '#1001', 'financial_status' => 'PAID', 'items' => [] } }
    end

    it 'adds the order card after the answer and places suggestion buttons after the card' do
      answer, order_card, suggestions = composer.messages

      expect(answer[:content_type]).to eq('text')
      expect(order_card).to include(content_type: 'cards', content: '1001')
      expect(suggestions).to include(content_type: 'input_select')
    end
  end

  it 'keeps a plain text answer when suggestions are suppressed' do
    answer = composer.messages(suppress_suggestions: true).first

    expect(answer).to include(content_type: 'text')
    expect(answer).not_to have_key(:content_attributes)
  end

  context 'with product cards' do
    let(:tool_state) { { Captain::Assistant::PRODUCT_HANDLES_STATE_KEY => %w[agras-t40], Captain::Assistant::PRODUCT_CACHE_STATE_KEY => cache } }
    let(:cache) do
      { 'agras-t40' => { 'handle' => 'agras-t40', 'title' => 'Spraying Drone', 'image_url' => 'https://cdn.shopify.com/t40.jpg',
                         'product_url' => 'https://example-store.com/products/agras-t40',
                         'variants' => [{ 'price' => '19999.00', 'currency' => 'EUR' }] } }
    end
    let(:response) { super().merge('product_handles' => %w[agras-t40]) }

    it 'adds the cards message after the answer and places suggestion buttons after the cards' do
      answer, cards, suggestions = composer.messages

      expect(answer).to include(content_type: 'text')
      expect(cards).to include(content_type: 'cards', content: 'Spraying Drone')
      expect(cards[:content_attributes][:items].first).to include('title' => 'Spraying Drone', 'media_url' => 'https://cdn.shopify.com/t40.jpg')
      expect(cards[:additional_attributes]).to include(agent_name: 'Store Bot', product_handles: %w[agras-t40])
      expect(suggestions).to include(content: nil, content_type: 'input_select')
    end

    context 'when the answer ends with a question' do
      let(:response) do
        {
          'agent_name' => 'Store Bot',
          'response_parts' => [{ 'text' => 'We have two spraying drones. Which tank size do you need?', 'citation_indexes' => [] }],
          'suggested_replies' => [{ 'label' => 'Up to 30 L', 'message' => 'I need a tank up to 30 L.' }],
          'product_handles' => %w[agras-t40]
        }
      end

      it 'shows the intro, then the cards, then the question with its buttons' do
        answer, cards, question = composer.messages

        expect(answer).to include(content: 'We have two spraying drones.', content_type: 'text')
        expect(answer[:additional_attributes][Captain::Assistant::ResponseParts::MESSAGE_ATTRIBUTE_KEY]).to eq(
          [{ 'text' => 'We have two spraying drones.', 'citation_indexes' => [] }]
        )
        expect(cards).to include(content_type: 'cards')
        expect(question).to include(content: 'Which tank size do you need?', content_type: 'input_select',
                                    additional_attributes: { agent_name: 'Store Bot' })
        expect(question[:content_attributes]).to eq(
          { items: [{ 'title' => 'Up to 30 L', 'value' => 'I need a tank up to 30 L.' }], submit_value: true }
        )
      end

      it 'keeps the question in the answer when suggestions are suppressed' do
        messages = composer.messages(suppress_suggestions: true)

        expect(messages.map { |message| message[:content_type] }).to eq(%w[text cards])
        expect(messages.first[:content]).to eq('We have two spraying drones. Which tank size do you need?')
      end
    end

    it 'shows products again when there is no conversation to remember them in' do
      conversation.messages.create!(
        message_type: :outgoing, account: account, inbox: inbox, content_type: 'cards', content: 'x',
        content_attributes: { items: [{ 'title' => 'x', 'description' => 'y', 'actions' => [link] }] },
        additional_attributes: { product_handles: %w[agras-t40] }
      )

      expect(composer.messages.map { |message| message[:content_type] }).to eq(%w[input_select])
      standalone = described_class.new(assistant: assistant, response: response, run_result: run_result)
      expect(standalone.messages.map { |message| message[:content_type] }).to eq(%w[text cards input_select])
    end
  end

  context 'when the answer ends with a follow-up question' do
    let(:response) do
      {
        'agent_name' => 'Store Bot',
        'response_parts' => [{ 'text' => 'You can pause a plan for up to three months. Which plan are you on?', 'citation_indexes' => [] }],
        'suggested_replies' => [{ 'label' => 'Monthly', 'message' => 'I am on the monthly plan.' }]
      }
    end

    it 'asks the question in its own bubble on the widget, with the buttons' do
      answer, question = composer.messages

      expect(answer).to include(content: 'You can pause a plan for up to three months.', content_type: 'text')
      expect(question).to include(content: 'Which plan are you on?', content_type: 'input_select')
    end

    it 'keeps one bubble when separate follow-up questions are off' do
      assistant.update!(config: assistant.config.merge('separate_follow_up' => false))

      expect(composer.messages.map { |message| message[:content] })
        .to eq(['You can pause a plan for up to three months. Which plan are you on?'])
    end

    it 'keeps one bubble on other channels' do
      inbox.update!(channel: create(:channel_sms, account: account))

      expect(composer.messages.size).to eq(1)
    end

    it 'still splits a qualification question when the switch is off' do
      assistant.update!(config: assistant.config.merge('separate_follow_up' => false))
      response['lead_qualification_question'] = true

      expect(composer.messages.map { |message| message[:content] })
        .to eq(['You can pause a plan for up to three months.', 'Which plan are you on?'])
    end

    it 'keeps a short greeting and its question together' do
      response['response_parts'] = [{ 'text' => 'Hi there! How can I help?', 'citation_indexes' => [] }]

      expect(composer.messages.map { |message| message[:content] }).to eq(['Hi there! How can I help?'])
    end
  end

  context 'when the model lists separate parts' do
    let(:assistant) do
      create(:captain_assistant, account: account,
                                 config: { 'suggested_replies' => true, 'max_suggested_replies' => 3, 'feature_citation' => true,
                                           'separate_follow_up' => false })
    end
    let(:response) do
      {
        'response_parts' => [
          { 'text' => 'Our trial lasts 14 days.', 'citation_indexes' => [1] },
          { 'text' => 'You can add teammates at any time.', 'citation_indexes' => [2] },
          { 'text' => 'Exports work on every plan.', 'citation_indexes' => [] },
          { 'text' => 'How large is your team?', 'citation_indexes' => [] }
        ],
        'separate_parts' => [3, 1, 2, 9],
        'suggested_replies' => ['Under 10']
      }
    end

    before do
      allow(assistant).to receive_messages(trusted_citation_urls: { 1 => 'https://example.com/trial', 2 => 'https://example.com/teams' },
                                           citation_titles: { 1 => 'Trial', 2 => 'Teams' })
    end

    it 'starts a new bubble at each listed part, at most three, with the buttons on the last one' do
      messages = composer.messages

      expect(messages.map { |message| message[:content] })
        .to eq(['Our trial lasts 14 days.', 'You can add teammates at any time.', "Exports work on every plan.\n\nHow large is your team?"])
      expect(messages.map { |message| message[:content_type] }).to eq(%w[text text input_select])
    end

    it 'keeps each source on the bubble that cites it' do
      first, second, last = composer.messages

      expect(first[:content_attributes]['captain_sources']).to eq([{ 'title' => 'Trial', 'url' => 'https://example.com/trial' }])
      expect(second[:content_attributes]['captain_sources']).to eq([{ 'title' => 'Teams', 'url' => 'https://example.com/teams' }])
      expect(last[:content_attributes]).not_to have_key('captain_sources')
    end

    it 'sends one message by email' do
      inbox.update!(channel: create(:channel_email, account: account))

      expect(composer.messages.size).to eq(1)
    end
  end

  describe '#welcome_message' do
    let(:contact) { create(:contact, account: account, name: 'jamie rivera') }
    let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
    let(:assistant) do
      create(:captain_assistant, account: account,
                                 config: { 'greeting_mode' => 'fixed', 'welcome_message' => 'Hi {{contact.first_name}}, welcome!' })
    end
    let(:tool_state) { { first_ai_reply: true } }

    it 'renders the fixed welcome for the first AI reply' do
      expect(composer.welcome_message).to eq(content: 'Hi Jamie, welcome!', content_type: 'text', additional_attributes: {})
    end

    it 'sends nothing after an earlier reply or an opener' do
      tool_state[:first_ai_reply] = false

      expect(composer.welcome_message).to be_nil
    end

    it 'sends nothing when the AI greets itself' do
      assistant.update!(config: assistant.config.merge('greeting_mode' => 'ai'))

      expect(composer.welcome_message).to be_nil
    end
  end

  context 'with a blank answer' do
    let(:response) { { 'response' => '', 'response_parts' => [] } }

    it 'falls back to the unusable-answer text and reflects it in the response parts' do
      answer = composer.messages.first
      text = I18n.t('conversations.captain.empty_response_handoff')

      expect(answer[:content]).to eq(text)
      expect(answer[:additional_attributes][Captain::Assistant::ResponseParts::MESSAGE_ATTRIBUTE_KEY]).to eq(
        [{ 'text' => text, 'citation_indexes' => [] }]
      )
      expect(composer.empty_response?).to be(true)
    end
  end
end

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

  context 'with labelled suggestions' do
    let(:response) do
      {
        'response' => 'Your order is paid.',
        'response_parts' => [{ 'text' => 'Your order is paid.', 'citation_indexes' => [] }],
        'suggested_replies' => [
          { 'label' => 'Shipping time', 'message' => 'When will order 1001 ship?' },
          { 'label' => 'A label that is far too long for a button', 'message' => 'Dropped' },
          { 'label' => 'Order items', 'message' => '' }
        ]
      }
    end

    it 'shows the short label and sends the full message, dropping labels that are too long' do
      expect(composer.messages.first[:content_attributes][:items]).to eq(
        [{ 'title' => 'Shipping time', 'value' => 'When will order 1001 ship?' }, { 'title' => 'Order items', 'value' => 'Order items' }]
      )
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

    it 'adds the cards message after the answer and drops the suggestion buttons' do
      answer, cards = composer.messages

      expect(answer).to include(content_type: 'text')
      expect(cards).to include(content_type: 'cards', content: 'Spraying Drone')
      expect(cards[:content_attributes][:items].first).to include('title' => 'Spraying Drone', 'media_url' => 'https://cdn.shopify.com/t40.jpg')
      expect(cards[:additional_attributes]).to include(agent_name: 'Store Bot', product_handles: %w[agras-t40])
    end

    it 'shows products again when there is no conversation to remember them in' do
      conversation.messages.create!(
        message_type: :outgoing, account: account, inbox: inbox, content_type: 'cards', content: 'x',
        content_attributes: { items: [{ 'title' => 'x', 'description' => 'y', 'actions' => [link] }] },
        additional_attributes: { product_handles: %w[agras-t40] }
      )

      expect(composer.messages.map { |message| message[:content_type] }).to eq(%w[input_select])
      standalone = described_class.new(assistant: assistant, response: response, run_result: run_result)
      expect(standalone.messages.map { |message| message[:content_type] }).to eq(%w[text cards])
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

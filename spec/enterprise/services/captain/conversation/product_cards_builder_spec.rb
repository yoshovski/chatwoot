# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Captain::Conversation::ProductCardsBuilder do
  subject(:builder) do
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
  let(:hook) do
    create(
      :integrations_hook,
      account: account,
      app_id: 'shopify',
      settings: {
        'state' => 'connected',
        'encrypted_tool_key' => Integrations::Hook.encrypt_shopify_tool_key('sat_tool_key_123'),
        'catalog_sync_enabled' => true,
        'storefront_url' => 'https://example-store.com'
      },
      reference_id: 'example-store.myshopify.com'
    )
  end
  let(:assistant) do
    create(
      :captain_assistant,
      account: account,
      config: {
        'product_cards' => true,
        'image_allowlist' => ['https://cdn.shopify.com/', 'https://example-store.com/cdn/']
      }
    )
  end
  let(:sat_client) { instance_double(ShopifyAgentTools::Client) }
  let(:tool_state) do
    {
      Captain::Assistant::PRODUCT_HANDLES_STATE_KEY => %w[agras-t40 mavic-3-pro no-img-item],
      :product_handles => %w[agras-t40 mavic-3-pro no-img-item]
    }
  end
  let(:run_result) do
    instance_double(Agents::RunResult, context: { state: tool_state })
  end
  let(:response) do
    {
      'agent_name' => 'Store Bot',
      'product_handles' => %w[agras-t40 mavic-3-pro fake-handle no-img-item]
    }
  end
  let(:t40_product) do
    {
      'id' => 'gid://shopify/Product/1',
      'handle' => 'agras-t40',
      'title' => 'DJI Agras T40 Spraying Drone',
      'description' => 'Flagship agricultural spraying drone with dual atomized spray system. In stock now.',
      'product_url' => 'https://example-store.myshopify.com/products/agras-t40',
      'image_url' => 'https://cdn.shopify.com/t40.jpg',
      'available' => true,
      'variants' => [
        { 'id' => 'v1', 'title' => 'Standard', 'price' => '19999.00', 'currency' => 'EUR', 'available' => true }
      ]
    }
  end
  let(:mavic_product) do
    {
      'id' => 'gid://shopify/Product/2',
      'handle' => 'mavic-3-pro',
      'title' => 'DJI Mavic 3 Pro',
      'description' => 'Triple-camera aerial photography drone.',
      'product_url' => 'https://example-store.myshopify.com/products/mavic-3-pro',
      'image_url' => 'https://example-store.com/cdn/mavic.png',
      'available' => true,
      'variants' => [
        { 'id' => 'v2', 'title' => 'Fly More', 'price' => '2099.00', 'currency' => 'EUR', 'available' => true }
      ]
    }
  end
  let(:no_img_product) do
    {
      'id' => 'gid://shopify/Product/3',
      'handle' => 'no-img-item',
      'title' => 'Drone Battery Charger',
      'description' => 'Fast charger hub for Agras batteries.',
      'product_url' => 'https://example-store.myshopify.com/products/no-img-item',
      'image_url' => nil,
      'available' => true,
      'variants' => [
        { 'id' => 'v3', 'title' => 'Hub', 'price' => '599.00', 'currency' => 'EUR', 'available' => true }
      ]
    }
  end

  before do
    hook
    allow(ShopifyAgentTools::Client).to receive(:new).and_return(sat_client)
    allow(sat_client).to receive(:get_product).with(handle: 'agras-t40').and_return(t40_product)
    allow(sat_client).to receive(:get_product).with(handle: 'mavic-3-pro').and_return(mavic_product)
    allow(sat_client).to receive(:get_product).with(handle: 'no-img-item').and_return(no_img_product)
  end

  describe '#products?' do
    it 'returns true when valid products are resolved' do
      expect(builder.products?).to be(true)
    end

    it 'returns false when assistant product_cards setting is off' do
      assistant.config['product_cards'] = false
      expect(builder.products?).to be(false)
    end

    it 'returns false when response has no product_handles' do
      response['product_handles'] = []
      expect(builder.products?).to be(false)
    end

    it 'returns false when tool run state returned no handles' do
      tool_state[Captain::Assistant::PRODUCT_HANDLES_STATE_KEY] = []
      tool_state[:product_handles] = []
      expect(builder.products?).to be(false)
    end
  end

  describe 'handle validation and filtering' do
    it 'drops handles not returned by tools in this run' do
      expect(builder.shown_handles).to contain_exactly('agras-t40', 'mavic-3-pro', 'no-img-item')
      expect(builder.shown_handles).not_to include('fake-handle')
    end

    it 'does not show a product again that a recent card message already showed' do
      create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing, sender: assistant,
                       content_type: :article, content_attributes: { items: [{ 'title' => 'DJI Agras T40' }] },
                       additional_attributes: { 'product_handles' => ['Agras-T40'] })

      expect(builder.shown_handles).to contain_exactly('mavic-3-pro', 'no-img-item')
    end

    it 'shows a product again once its card is older than the recent messages' do
      create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing, sender: assistant,
                       content_type: :article, content_attributes: { items: [{ 'title' => 'DJI Agras T40' }] },
                       additional_attributes: { 'product_handles' => ['agras-t40'] })
      create_list(:message, described_class::RECENT_MESSAGES, conversation: conversation, account: account, inbox: inbox)

      expect(builder.shown_handles).to include('agras-t40')
    end
  end

  describe 'card formatting and image allowlist' do
    it 'puts products with allowed images into cards_items' do
      cards = builder.cards_items
      expect(cards.size).to eq(2)

      t40_card = cards.find { |c| c['title'].include?('Agras T40') }
      expect(t40_card['media_url']).to eq('https://cdn.shopify.com/t40.jpg')
      expect(t40_card['description']).to include('19999.00 EUR — Flagship agricultural spraying drone')
      expect(t40_card['description']).not_to include('In stock')
      expected_actions = [{ 'type' => 'link', 'text' => 'View product', 'uri' => 'https://example-store.myshopify.com/products/agras-t40' }]
      expect(t40_card['actions']).to eq(expected_actions)
    end

    it 'puts products without an allowed image into article_items' do
      articles = builder.article_items
      expect(articles.size).to eq(1)

      article = articles.first
      expect(article['title']).to eq('Drone Battery Charger')
      expect(article['description']).to include('599.00 EUR')
      expect(article['link']).to eq('https://example-store.myshopify.com/products/no-img-item')
    end

    it 'treats an untrusted image url as not allowed and puts product in article_items' do
      mavic_product['image_url'] = 'https://untrusted-image-host.com/drone.png'
      expect(builder.cards_items.size).to eq(1)
      expect(builder.article_items.size).to eq(2)
    end

    context 'when hide_stock is enabled' do
      before do
        assistant.config['hide_stock'] = true
        t40_product['description'] = 'Flagship agricultural spraying drone. In stock now.'
        t40_product['title'] = 'DJI Agras T40 (In Stock)'
        no_img_product['description'] = 'Fast charger hub for Agras batteries. In stock.'
        no_img_product['title'] = 'Drone Battery Charger - Ready to ship'
      end

      it 'strips stock phrases from card titles and descriptions' do
        cards = builder.cards_items
        t40_card = cards.find { |c| c['title'].include?('Agras T40') }

        expect(t40_card['title']).to eq('DJI Agras T40')
        expect(t40_card['description']).to include('19999.00 EUR — Flagship agricultural spraying drone')
        expect(t40_card['description']).not_to include('In stock')
      end

      it 'strips stock phrases from article titles and descriptions' do
        articles = builder.article_items
        article = articles.first

        expect(article['title']).to eq('Drone Battery Charger')
        expect(article['description']).to include('599.00 EUR — Fast charger hub for Agras batteries')
        expect(article['description']).not_to include('In stock')
      end
    end
  end

  describe '#clean_prose_content' do
    it 'removes bare product URLs and images from prose' do
      prose = 'We recommend the Agras T40 https://example-store.myshopify.com/products/agras-t40 for your field. ' \
              '![drone](https://cdn.shopify.com/drone.jpg) It is powerful!'

      cleaned = builder.clean_prose_content(prose)
      expect(cleaned).to eq('We recommend the Agras T40 for your field. It is powerful!')
      expect(cleaned).not_to include('https://example-store.myshopify.com/products/agras-t40')
      expect(cleaned).not_to include('![drone]')
    end

    it 'converts markdown links to product into plain link text' do
      prose = 'Check out [DJI Agras T40](https://example-store.myshopify.com/products/agras-t40) today.'
      expect(builder.clean_prose_content(prose)).to eq('Check out DJI Agras T40 today.')
    end

    it 'provides friendly fallback text when the entire message is just product URLs' do
      prose = 'https://example-store.myshopify.com/products/agras-t40'
      expect(builder.clean_prose_content(prose)).to eq('Here are the recommended products:')
    end
  end

  describe '#filter_citation_urls' do
    it 'removes citations pointing to products shown in cards or articles' do
      citations = {
        1 => 'https://example-store.myshopify.com/products/agras-t40',
        2 => 'https://example-store.com/faq/shipping',
        3 => 'https://example-store.myshopify.com/products/other-item'
      }

      filtered = builder.filter_citation_urls(citations)
      expect(filtered.keys).to contain_exactly(2, 3)
      expect(filtered[1]).to be_nil
      expect(filtered[2]).to eq('https://example-store.com/faq/shipping')
    end
  end

  describe '#post_messages!' do
    let(:messages) { builder.post_messages!(preserve_waiting_since: true, agent_name: 'Store Bot') }

    it 'creates a cards message for products with allowed images' do
      cards_msg = messages.find { |m| m.content_type == 'cards' }

      expect(cards_msg).to be_present
      expect(cards_msg.content_attributes['items'].size).to eq(2)
      expect(cards_msg.additional_attributes['agent_name']).to eq('Store Bot')
      expect(cards_msg.additional_attributes['product_handles']).to contain_exactly('agras-t40', 'mavic-3-pro', 'no-img-item')
      expect(cards_msg.preserve_waiting_since).to be(true)
    end

    it 'creates an article message for products without an allowed image' do
      article_msg = messages.find { |m| m.content_type == 'article' }

      expect(article_msg).to be_present
      expect(article_msg.content_attributes['items'].size).to eq(1)
      expect(article_msg.additional_attributes['agent_name']).to eq('Store Bot')
      expect(article_msg.preserve_waiting_since).to be(true)
    end
  end
end

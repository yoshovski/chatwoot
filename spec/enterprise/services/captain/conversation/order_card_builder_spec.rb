# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Captain::Conversation::OrderCardBuilder do
  subject(:card) { described_class.new(assistant: assistant, run_result: run_result).build_messages.first }

  let(:assistant) { create(:captain_assistant) }
  let(:run_result) { instance_double(Agents::RunResult, context: { state: { Captain::Assistant::ORDER_STATE_KEY => order } }) }
  let(:order) do
    {
      'order_number' => '#SHOP_1001',
      'created_at' => '2026-10-09T15:30:00Z',
      'financial_status' => 'PAID',
      'fulfillment_status' => 'UNFULFILLED',
      'status_page_url' => 'https://store.example/orders/abc',
      'items' => [{ 'name' => 'Parachute X200', 'quantity' => 1 }],
      'fulfillments' => []
    }
  end
  let(:item) { card[:content_attributes][:items].first }

  it 'shows an unshipped paid order with plain status words and a link to the order page' do
    expect(card).to include(content: 'Order SHOP_1001 · Oct 9, 2026', content_type: 'cards')
    expect(item['description']).to eq("Paid · Not shipped yet\n1× Parachute X200")
    expect(item['actions']).to eq([{ 'type' => 'link', 'text' => 'View order', 'uri' => 'https://store.example/orders/abc' }])
    expect(item).not_to have_key('media_url')
  end

  context 'when the order is on its way' do
    before do
      order.merge!(
        'fulfillment_status' => 'FULFILLED',
        'fulfillments' => [{ 'display_status' => 'IN_TRANSIT', 'estimated_delivery_at' => '2026-10-14T00:00:00Z',
                             'tracking' => [{ 'company' => 'DHL', 'number' => '123', 'url' => 'https://carrier.example/track/123' }] }]
      )
    end

    it 'shows the shipment status, the arrival date and a tracking button' do
      expect(item['description']).to start_with('Paid · In transit · Arrives Oct 14')
      expect(item['actions']).to eq([{ 'type' => 'link', 'text' => 'Track package', 'uri' => 'https://carrier.example/track/123' }])
    end
  end

  context 'with many items and no links' do
    before do
      order.merge!('status_page_url' => nil, 'items' => (1..5).map { |n| { 'name' => "Item #{n}", 'quantity' => n } })
    end

    it 'lists the first three items and counts the rest' do
      expect(item['description'].lines.map(&:strip)).to eq(['Paid · Not shipped yet', '1× Item 1', '2× Item 2', '3× Item 3', '+2 more items'])
      expect(item['actions']).to eq([])
    end
  end

  context 'without an order in the run' do
    let(:run_result) { instance_double(Agents::RunResult, context: { state: {} }) }

    it 'builds nothing' do
      expect(described_class.new(assistant: assistant, run_result: run_result).build_messages).to eq([])
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'
require 'active_support/all'

module Captain; end
module Captain::Tools; end

require_relative '../../../../../enterprise/lib/captain/tools/base_public_tool'
require_relative '../../../../../enterprise/lib/captain/tools/shopify_tool_helpers'
require_relative '../../../../../enterprise/lib/captain/tools/track_order_tool'

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe Captain::Tools::TrackOrderTool do
  let(:account) do
    double(
      'Account',
      id: 1,
      name: 'Test Store',
      custom_attributes: {},
      hooks: hooks_relation,
      feature_enabled?: true
    )
  end
  let(:hooks_relation) { double('hooks_relation') }
  let(:assistant) do
    double(
      'Captain::Assistant',
      account: account,
      account_id: 1,
      config: {},
      shopify_tools_available?: true
    )
  end
  let(:tool) { described_class.new(assistant) }
  let(:tool_context) { Struct.new(:state).new({}) }
  let(:hook) do
    double(
      'Integrations::Hook',
      app_id: 'shopify',
      shopify?: true,
      shopify_connected?: true,
      shopify_tool_key: 'sat_key',
      shopify_sat_client: sat_client,
      reference_id: 'test.myshopify.com',
      settings: { 'state' => 'connected' }
    )
  end
  let(:sat_client) { double('ShopifyAgentTools::Client') }

  before do
    allow(hooks_relation).to receive(:find_by).with(app_id: 'shopify').and_return(hook)
    allow(tool).to receive(:log_tool_usage)
  end

  describe '#description and #parameters' do
    it 'has description and expected params' do
      expect(tool.description).to include('Track a customer order')
      expect(tool.parameters).to have_key(:order_number)
      expect(tool.parameters).to have_key(:customer_email)
    end
  end

  describe '#active?' do
    it 'returns true when shopify tools are available' do
      expect(tool.active?).to be true
    end

    it 'returns false when shopify tools are not available' do
      allow(assistant).to receive(:shopify_tools_available?).and_return(false)
      expect(tool.active?).to be false
    end
  end

  describe '#perform' do
    it 'fails validation when order_number is blank' do
      result = tool.perform(tool_context, order_number: '', customer_email: 'customer@example.com')
      expect(result).to include('Order number is required')
    end

    it 'fails validation when customer_email is blank' do
      result = tool.perform(tool_context, order_number: '#1001', customer_email: '')
      expect(result).to include('Customer email is required')
    end

    it 'fails validation when customer_email is invalid' do
      result = tool.perform(tool_context, order_number: '#1001', customer_email: 'notanemail')
      expect(result).to include('email address')
      expect(result).to include('is invalid')
    end

    it 'returns message when order is not found or email does not match' do
      allow(sat_client).to receive(:track_order).with(
        order_number: '#1001',
        customer_email: 'customer@example.com'
      ).and_return({ 'found' => false })

      result = tool.perform(tool_context, order_number: '#1001', customer_email: 'customer@example.com')
      expect(result).to include('No order was found matching order number \'#1001\' and email \'customer@example.com\'')
    end

    it 'formats order details and tracking when order is found' do
      order_data = {
        'found' => true,
        'order_number' => '#1001',
        'fulfillment_status' => 'In transit',
        'financial_status' => 'PAID',
        'created_at' => '2026-10-01T12:00:00Z',
        'status_page_url' => 'https://test.myshopify.com/orders/status/xyz',
        'items' => [
          { 'name' => 'DJI Battery', 'quantity' => 2 }
        ],
        'fulfillments' => [
          {
            'status' => 'in_transit',
            'display_status' => 'Out for delivery',
            'estimated_delivery_at' => '2026-10-07',
            'tracking' => [
              { 'company' => 'DHL Express', 'number' => 'DHL123456', 'url' => 'https://dhl.com/track/123' }
            ],
            'items' => [
              { 'name' => 'DJI Battery', 'quantity' => 2 }
            ]
          }
        ]
      }

      allow(sat_client).to receive(:track_order).with(
        order_number: '#1001',
        customer_email: 'customer@example.com'
      ).and_return(order_data)

      result = tool.perform(tool_context, order_number: '#1001', customer_email: 'customer@example.com')

      expect(result).to include(
        'Order: #1001',
        'Status: In transit',
        'Financial status: PAID',
        'Shipment status: Out for delivery',
        'Estimated delivery: 2026-10-07',
        'DHL Express DHL123456',
        'Shipped items: DJI Battery (x2)',
        'https://test.myshopify.com/orders/status/xyz'
      )
    end

    it 'returns failure result when Shopify is disconnected' do
      allow(assistant).to receive(:shopify_tools_available?).and_return(false)

      result = tool.perform(tool_context, order_number: '#1001', customer_email: 'customer@example.com')
      expect(result).to include('Shopify is not connected for this account')
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles

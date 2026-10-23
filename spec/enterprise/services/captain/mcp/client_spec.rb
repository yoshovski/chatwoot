require 'rails_helper'

RSpec.describe Captain::Mcp::Client do
  let(:account) { create(:account) }
  let(:server) do
    account.captain_mcp_servers.create!(name: 'Billing', endpoint_url: 'https://example.com/mcp', auth_type: 'bearer', auth_token: 'secret')
  end
  let(:client) { described_class.new(server) }

  def rpc_result(id, result) = { jsonrpc: '2.0', id: id, result: result }.to_json

  before do
    stub_request(:post, 'https://example.com/mcp').with(body: hash_including('method' => 'initialize'))
                                                  .to_return(status: 200, body: rpc_result(1, { protocolVersion: '2025-06-18' }),
                                                             headers: { 'Content-Type' => 'application/json', 'Mcp-Session-Id' => 'abc' })
    stub_request(:post, 'https://example.com/mcp').with(body: hash_including('method' => 'notifications/initialized'))
                                                  .to_return(status: 202)
  end

  it 'lists tools across pages, reading SSE replies and reusing the session' do
    stub_request(:post, 'https://example.com/mcp')
      .with(body: hash_including('method' => 'tools/list',
                                 'params' => {}), headers: { 'Mcp-Session-Id' => 'abc', 'Authorization' => 'Bearer secret' })
      .to_return(status: 200, body: "event: message\ndata: #{rpc_result(2, { tools: [{ name: 'refund' }], nextCursor: 'p2' })}\n\n",
                 headers: { 'Content-Type' => 'text/event-stream' })
    stub_request(:post, 'https://example.com/mcp')
      .with(body: hash_including('method' => 'tools/list', 'params' => { 'cursor' => 'p2' }))
      .to_return(status: 200, body: rpc_result(3, { tools: [{ name: 'invoice' }] }), headers: { 'Content-Type' => 'application/json' })

    expect(client.list_tools.pluck('name')).to eq(%w[refund invoice])
  end

  it 'returns text content and marks tool errors' do
    stub_request(:post, 'https://example.com/mcp').with(body: hash_including('method' => 'tools/call'))
                                                  .to_return(status: 200, body: rpc_result(2, { content: [{ type: 'text', text: 'Not allowed' }],
                                                                                                isError: true }),
                                                             headers: { 'Content-Type' => 'application/json' })

    expect(client.call_tool('refund', { 'order' => '1' })).to eq('ERROR: Not allowed')
  end

  it 'raises on a JSON-RPC error' do
    stub_request(:post, 'https://example.com/mcp').with(body: hash_including('method' => 'tools/list'))
                                                  .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                                                             body: { jsonrpc: '2.0', id: 2, error: { code: -32_601, message: 'Unknown' } }.to_json)

    expect { client.list_tools }.to raise_error(described_class::Error, 'Unknown')
  end
end

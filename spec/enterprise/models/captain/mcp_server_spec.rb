require 'rails_helper'

RSpec.describe Captain::McpServer do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:server) { account.captain_mcp_servers.create!(name: 'Billing', endpoint_url: 'https://example.com/mcp') }
  let(:client) { instance_double(Captain::Mcp::Client) }

  before { allow(Captain::Mcp::Client).to receive(:new).and_return(client) }

  it 'keeps enabled tools enabled and starts new tools disabled' do
    server.update!(tools: [{ 'name' => 'refund', 'enabled' => true }])
    allow(client).to receive(:list_tools).and_return([{ 'name' => 'refund', 'description' => 'Refund an order' },
                                                      { 'name' => 'get invoice', 'inputSchema' => { 'type' => 'object' } }])

    server.sync_tools!

    expect(server.status).to eq('connected')
    expect(server.tools.map { |tool| tool.values_at('id', 'enabled') }).to eq([["mcp#{server.id}_refund", true],
                                                                               ["mcp#{server.id}_get_invoice", false]])
  end

  it 'records the error when the server cannot be reached' do
    allow(client).to receive(:list_tools).and_raise(Captain::Mcp::Client::Error, 'timeout')

    server.sync_tools!

    expect(server.reload.values_at(:status, :last_error)).to eq(%w[failed timeout])
  end

  it 'offers only enabled tools to scenarios and calls them on the server' do
    server.update!(tools: [{ 'id' => "mcp#{server.id}_refund", 'name' => 'refund', 'title' => 'Refund', 'enabled' => true,
                             'input_schema' => { 'type' => 'object', 'properties' => { 'order' => { 'type' => 'string' } } } },
                           { 'id' => "mcp#{server.id}_delete", 'name' => 'delete', 'title' => 'Delete', 'enabled' => false }])
    allow(client).to receive(:call_tool).with('refund', { order: '7' }).and_return('Refunded')

    expect(assistant.available_tool_ids).to include("mcp#{server.id}_refund")
    expect(assistant.available_tool_ids).not_to include("mcp#{server.id}_delete")
    tool = server.agent_tool("mcp#{server.id}_refund", assistant)
    expect(tool.name).to eq("mcp#{server.id}_refund")
    expect(tool.perform(Struct.new(:state).new({}), order: '7')).to eq('Refunded')
    expect(server.agent_tool("mcp#{server.id}_delete", assistant)).to be_nil
  end

  it 'requires a token for authenticated servers' do
    expect(account.captain_mcp_servers.new(name: 'X', endpoint_url: 'https://example.com/mcp', auth_type: 'bearer')).not_to be_valid
  end
end

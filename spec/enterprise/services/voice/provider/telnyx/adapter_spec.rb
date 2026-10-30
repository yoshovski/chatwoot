# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Voice::Provider::Telnyx::Adapter do
  let(:channel) { create(:channel_sms, :telnyx_voice, phone_number: '+15551230013') }

  it 'dials the contact through the TeXML application and returns our own call reference' do
    sent = nil
    stub_request(:post, 'https://api.telnyx.com/v2/texml/Accounts/acct-uuid/Calls')
      .with { |req| sent = JSON.parse(req.body) }
      .to_return(status: 200, body: { status: 'queued' }.to_json, headers: { 'Content-Type' => 'application/json' })

    result = described_class.new(channel).initiate_call(to: '+15550001234')

    expect(result[:provider]).to eq('telnyx')
    expect(result[:call_sid]).to start_with('telnyx-')
    expect(sent.values_at('To', 'From', 'ApplicationSid')).to eq(['+15550001234', '+15551230013', 'texml-1'])
    expect(sent['Url']).to include("call_ref=#{result[:call_sid]}")
    expect(sent['StatusCallback']).to include("call_ref=#{result[:call_sid]}")
  end
end

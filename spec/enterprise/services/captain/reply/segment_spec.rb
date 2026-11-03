require 'rails_helper'

RSpec.describe Captain::Reply::Segment do
  it 'builds a payload with the prose parts and without empty keys' do
    part = Captain::Reply::Part.new(text: 'Sync runs hourly.')
    segment = described_class.new(kind: 'answer', text: 'Sync runs hourly.', parts: [part], content_type: 'text')

    expect(segment).to be_prose
    expect(segment.payload).to eq(
      content: 'Sync runs hourly.', content_type: 'text',
      additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => 'Sync runs hourly.', 'citation_indexes' => [] }] }
    )
  end

  it 'wraps a finished payload' do
    payload = { content: '1001', content_type: 'cards', content_attributes: { items: [{ 'title' => '1001' }] } }
    segment = described_class.from_payload('order_card', payload)

    expect(segment).not_to be_prose
    expect(segment).to be_buttons
    expect(segment.payload).to eq(payload)
  end
end

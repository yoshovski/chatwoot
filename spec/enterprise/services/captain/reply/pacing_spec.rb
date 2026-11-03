require 'rails_helper'

RSpec.describe Captain::Reply::Pacing do
  let(:now) { Time.zone.parse('2026-11-04 10:00:00') }
  let(:message) { instance_double(Message, created_at: now - 5.seconds) }

  def offsets(payloads, responding_to: message)
    stamped = described_class.stamp(payloads, responding_to: responding_to, now: now)
    stamped.map { |payload| payload[:additional_attributes]['captain_reveal_offset_ms'] }
  end

  it 'shares one reply id and keeps the existing attributes' do
    stamped = described_class.stamp([{ content: 'Hi', additional_attributes: { 'captain_segment_kinds' => ['answer'] } }, { content: 'More?' }],
                                    responding_to: message, now: now)

    expect(stamped.map { |payload| payload[:additional_attributes]['captain_reply_id'] }.uniq.size).to eq(1)
    expect(stamped.first[:additional_attributes]).to include('captain_segment_kinds' => ['answer'])
  end

  it 'reveals a single bubble at once when generation took longer than the minimum typing time' do
    expect(offsets([{ content: 'Hello there' }])).to eq([0])
  end

  it 'holds the first bubble for the rest of the minimum typing time' do
    quick = instance_double(Message, created_at: now - 0.4.seconds)

    expect(offsets([{ content: 'Hello' }], responding_to: quick)).to eq([600])
  end

  it 'pauses before each later text bubble by its length, clamped at both ends' do
    payloads = [{ content: 'First' }, { content: 'a' * 50 }, { content: 'b' * 10 }]

    # 500 + 12 * 50 = 1100; 500 + 12 * 10 = 620 -> 800
    expect(offsets(payloads)).to eq([0, 1100, 1900])
    expect(offsets([{ content: 'First' }, { content: 'c' * 400 }])).to eq([0, 2500])
  end

  it 'gives cards and forms the offset of the bubble before them' do
    payloads = [{ content: 'Answer' }, { content: nil, content_type: 'cards' }, { content: 'd' * 50, content_type: 'text' },
                { content: 'Pick one', content_type: 'input_select' }]

    expect(offsets(payloads)).to eq([0, 0, 1100, 1100])
  end
end

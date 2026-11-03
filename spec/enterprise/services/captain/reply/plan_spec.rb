require 'rails_helper'

RSpec.describe Captain::Reply::Plan do
  let(:greeting_part) { Captain::Reply::Part.new(text: 'Hi there!', kind: :greeting) }
  let(:answer_part) { Captain::Reply::Part.new(text: 'Sync runs hourly.', citation_indexes: [1], model_index: 0) }
  let(:segments) do
    [Captain::Reply::Segment.new(kind: 'greeting', text: 'Hi there!', parts: [greeting_part], attach: :next),
     Captain::Reply::Segment.new(kind: 'answer', text: "Hi there!\n\nSync runs hourly.", parts: [answer_part], content_type: 'text',
                                 additional_attributes: { agent_name: 'Lumen' }),
     Captain::Reply::Segment.new(kind: 'order_card', text: '1001', content_type: 'cards', content_attributes: { items: [] })]
  end

  it 'merges an attached segment into the next bubble and names the kinds of every payload' do
    expect(described_class.new(segments).payloads).to eq(
      [{ content: "Hi there!\n\nSync runs hourly.", content_type: 'text',
         additional_attributes: { :agent_name => 'Lumen', 'captain_segment_kinds' => %w[greeting answer],
                                  'captain_v2_response_parts' => [{ 'text' => 'Hi there!', 'citation_indexes' => [] },
                                                                  { 'text' => 'Sync runs hourly.', 'citation_indexes' => [1] }] } },
       { content: '1001', content_type: 'cards', content_attributes: { items: [] },
         additional_attributes: { 'captain_segment_kinds' => %w[order_card] } }]
    )
  end

  it 'leaves the kinds out on request and keeps a nil content' do
    buttons = Captain::Reply::Segment.new(kind: 'question', content_type: 'input_select', content_attributes: { items: [] })

    expect(described_class.new([buttons]).payloads(segment_kinds: false))
      .to eq([{ content: nil, content_type: 'input_select', content_attributes: { items: [] } }])
  end
end

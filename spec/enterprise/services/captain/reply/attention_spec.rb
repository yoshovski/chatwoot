require 'rails_helper'

RSpec.describe Captain::Reply::Attention do
  let(:assistant) { create(:captain_assistant) }

  def intent(payloads, response: {}, suppressed: false)
    described_class.stamp(payloads, response: response, assistant: assistant, suppressed: suppressed)
                   .map { |payload| payload[:additional_attributes]['captain_attention_intent'] }.uniq.sole
  end

  def text(content, kinds = ['answer']) = { content: content, additional_attributes: { 'captain_segment_kinds' => kinds } }

  it 'marks a complete answer, even when optional buttons follow it' do
    buttons = { content: '', content_type: 'input_select', content_attributes: { 'items' => [{ 'title' => 'Batteries' }] } }

    expect(intent([text('The warranty is 12 months.'), buttons])).to eq('answer_complete')
  end

  it 'marks a reply that asks a clarifying question as waiting for an answer' do
    expect(intent([text('Which drone do you have?', ['question'])])).to eq('awaiting_answer')
    expect(intent([text('It depends.')], response: { 'follow_up' => { 'kind' => 'clarification' } })).to eq('awaiting_answer')
  end

  it 'treats an offered next step as already offering more help' do
    expect(intent([text('Done.')], response: { 'follow_up' => { 'kind' => 'next_step' } })).to eq('offered')
  end

  it 'stays quiet for forms, handoffs and unclassified questions' do
    expect(intent([{ content: 'Your email', content_type: 'form' }])).to eq('none')
    expect(intent([text('The warranty is 12 months.')], suppressed: true)).to eq('none')
    expect(intent([text('Did that help?')])).to eq('none')
  end

  it 'marks only the last bubble as the end of the reply' do
    stamped = described_class.stamp([text('One.'), text('Two.')], response: {}, assistant: assistant)

    expect(stamped.map { |payload| payload[:additional_attributes]['captain_reply_final'] }).to eq([false, true])
  end
end

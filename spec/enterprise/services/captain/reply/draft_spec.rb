require 'rails_helper'

RSpec.describe Captain::Reply::Draft do
  let(:welcome) { 'Hello and welcome! I can certainly help you with that.' }

  def draft(first_text, rest: [{ 'text' => 'Open Settings.', 'citation_indexes' => [2] }], first_citations: [])
    described_class.from_response({ 'welcome' => welcome, 'separate_parts' => [1, 'x'],
                                    'response_parts' => [{ 'text' => first_text, 'citation_indexes' => first_citations }, *rest] })
  end

  it 'reads the model fields and keeps the welcome apart from the parts' do
    response = { 'agent_name' => 'Lumen', 'welcome' => 'Hi there!', 'separate_parts' => [1, 'x'], 'suggested_replies' => ['Sync now'],
                 'product_handles' => %w[trail-boot], 'handoff_requested' => true, 'lead_qualification_question' => true,
                 'response_parts' => [{ 'text' => 'Sync runs hourly [1].', 'citation_indexes' => [1, 0] }, { 'text' => ' ' },
                                      { 'text' => 'Offline works.', 'citation_indexes' => [] }] }

    result = described_class.from_response(response)

    expect(result).to have_attributes(welcome: 'Hi there!', welcome_guard: nil, separate_part_indexes: [1], follow_up: nil,
                                      suggestions: ['Sync now'], product_handles: %w[trail-boot], handoff_requested: true,
                                      qualification_question: true, agent_name: 'Lumen', raw: response)
    expect(result.parts.map { |part| [part.text, part.citation_indexes, part.model_index] })
      .to eq([['Sync runs hourly.', [1], 0], ['Offline works.', [], 1]])
    expect(result.welcome_part).to have_attributes(text: 'Hi there!', kind: :greeting)
  end

  it 'reads plain text and replies without response parts' do
    expect(described_class.from_response('Sure.').parts.map(&:text)).to eq(['Sure.'])
    expect(described_class.from_response({ 'response' => 'Sure.', 'welcome' => 'Hi!' })).to have_attributes(welcome: nil)
    expect(described_class.from_response({ 'response' => 'Sure.' }).parts.map(&:text)).to eq(['Sure.'])
  end

  it 'drops a first part that repeats the welcome and moves its citations, keeping the model indexes' do
    result = draft('hello AND welcome 👋 I can certainly help you with that', first_citations: [1])

    expect(result.welcome_guard).to eq('dropped')
    expect(result.parts.map { |part| [part.text, part.citation_indexes, part.model_index] }).to eq([['Open Settings.', [1, 2], 1]])
  end

  it 'strips the welcome or another greeting from the start of the first part' do
    expect(draft("#{welcome} 😊 To sync, open Settings.").then { |result| [result.welcome_guard, result.parts.first.text] })
      .to eq(['stripped', 'To sync, open Settings.'])
    expect(draft('Hi there! To sync, open Settings.').parts.first.text).to eq('To sync, open Settings.')
  end

  it 'keeps the parts when nothing of the answer would remain or the first part does not repeat the welcome' do
    expect(draft(welcome, rest: [])).to have_attributes(welcome_guard: nil)
    expect(draft('Hello and welcome to Lumen Notes, open Settings.')).to have_attributes(welcome_guard: nil)
  end
end

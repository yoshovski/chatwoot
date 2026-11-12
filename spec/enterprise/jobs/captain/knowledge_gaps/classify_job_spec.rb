require 'rails_helper'

# 30 mixed messages from spec/fixtures/files/captain/knowledge_gap_messages.yml, each from its own conversation, go
# through the recorder and ClassifyJob with the model stubbed to the fixture's answers. The result must be one gap per
# expected group. `rake captain:knowledge_gaps:eval` runs the same messages against the real model.
RSpec.describe Captain::KnowledgeGaps::ClassifyJob do
  let(:fixture) { YAML.load_file(Rails.root.join('spec/fixtures/files/captain/knowledge_gap_messages.yml')) }
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:chat) { instance_double(RubyLLM::Chat) }
  let(:embedder) { instance_double(Captain::Llm::EmbeddingService) }

  before do
    groups = fixture.each_with_index.flat_map do |(name, group), axis|
      group['messages'].map { |message| [message, group.merge('name' => name, 'axis' => axis)] }
    end.to_h
    allow(Captain::Assistant::TieredLlmClient).to receive(:chat).and_return(chat)
    allow(chat).to receive_messages(with_params: chat, with_instructions: chat)
    allow(chat).to receive(:ask) do |input|
      group = groups.fetch(JSON.parse(input)['message'])
      content = { kind: group['kind'], canonical_question: group['question'], topic: group['topic'],
                  language: group['language'] || 'en', intent: group['intent'] }
      instance_double(RubyLLM::Message, content: content.to_json)
    end
    # The rewritten questions of one group point the same way, with a small per-call wobble; groups are orthogonal.
    allow(Captain::Llm::EmbeddingService).to receive(:new).and_return(embedder)
    axis_of = fixture.each_with_index.to_h { |(_, group), axis| [group['question'], axis] }
    allow(embedder).to receive(:get_embedding) do |question|
      Array.new(1536, 0.0).tap do |vector|
        vector[axis_of.fetch(question)] = 1.0
        vector[1535] = rand * 0.1
      end
    end
  end

  it 'turns 30 messages into one gap per expected group' do
    perform_enqueued_jobs(only: described_class) do
      fixture.each_value do |group|
        group['messages'].each do |message|
          Captain::KnowledgeGaps::Recorder.new(assistant: assistant, conversation: create(:conversation, account: account, inbox: inbox),
                                               question: message, reason: 'no_source').record
        end
      end
    end

    gaps = assistant.knowledge_gaps.includes(:occurrences).index_by(&:question)
    expect(gaps.size).to eq(fixture.size)
    fixture.each_value do |group|
      expect(gaps.fetch(group['question'])).to have_attributes(kind: group['kind'], intent: group['intent'], topic: group['topic'],
                                                               occurrences_count: group['messages'].size)
      expect(gaps.fetch(group['question']).occurrences.map(&:question)).to match_array(group['messages'])
    end
    expect(assistant.knowledge_gaps.unanswered.pluck(:question)).to match_array(
      fixture.values.select { |group| group['kind'] == 'knowledge' && group['messages'].size >= 2 }.pluck('question')
    )
    expect(assistant.knowledge_gaps.open.action_request.group(:intent).sum(:occurrences_count))
      .to eq('order_status' => 3, 'cancel' => 2, 'return' => 2, 'booking' => 1)
  end
end

require 'rails_helper'

RSpec.describe Captain::KnowledgeGaps::Recorder do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:other_conversation) { create(:conversation, account: account) }

  def record(question, conversation:, reason: 'no_source')
    described_class.new(assistant: assistant, conversation: conversation, question: question, reason: reason).record
  end

  it 'groups the same question from different conversations into one gap' do
    record('Do you ship to Spain?', conversation: conversation)
    gap = record('do you ship to spain', conversation: other_conversation, reason: 'handoff')

    expect(assistant.knowledge_gaps.count).to eq(1)
    expect(gap.reload).to have_attributes(occurrences_count: 2, question: 'do you ship to spain', status: 'open')
    expect(gap.occurrences.pluck(:reason)).to contain_exactly('no_source', 'handoff')
  end

  it 'counts a conversation once' do
    record('Do you ship to Spain?', conversation: conversation)
    gap = record('Do you ship to Spain?', conversation: conversation)

    expect(gap.reload.occurrences_count).to eq(1)
  end

  it 'keeps a dismissed gap dismissed' do
    record('Do you ship to Spain?', conversation: conversation).dismissed!
    gap = record('Do you ship to Spain?', conversation: other_conversation)

    expect(gap.reload).to have_attributes(status: 'dismissed', occurrences_count: 2)
  end

  it 'reopens an answered gap' do
    record('Do you ship to Spain?', conversation: conversation).answered!
    gap = record('Do you ship to Spain?', conversation: other_conversation)

    expect(gap.reload.status).to eq('open')
  end

  it 'skips blank questions' do
    expect(record('  ?! ', conversation: conversation)).to be_nil
    expect(assistant.knowledge_gaps).to be_empty
  end
end

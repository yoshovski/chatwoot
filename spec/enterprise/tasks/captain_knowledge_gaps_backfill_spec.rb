require 'rails_helper'
require 'rake'

RSpec.describe 'captain:knowledge_gaps:backfill' do # rubocop:disable RSpec/DescribeClass
  let(:assistant) { create(:captain_assistant) }
  let(:task) do
    unless Rake::Task.task_defined?('captain:knowledge_gaps:backfill')
      load Rails.root.join('enterprise/lib/tasks/captain_knowledge_gaps.rake')
      Rake::Task.define_task(:environment)
    end
    Rake::Task['captain:knowledge_gaps:backfill']
  end

  before { task.reenable }

  it 'copies the raw text to old occurrences and classifies the unclassified gaps, leaving failures for the next run' do
    old_gap = assistant.knowledge_gaps.create!(question: 'do you ship to spain', normalized_question: 'do ship to spain',
                                               last_seen_at: Time.current)
    old_gap.occurrences.create!(conversation: create(:conversation, account: assistant.account), reason: 'handoff')
    failing_gap = assistant.knowledge_gaps.create!(question: 'hm', normalized_question: 'hm', last_seen_at: Time.current)
    allow(Captain::KnowledgeGaps::Classification).to receive(:new).and_call_original
    allow(Captain::KnowledgeGaps::Classification).to receive(:new).with(old_gap) do
      instance_double(Captain::KnowledgeGaps::Classification, perform: old_gap.knowledge!)
    end
    allow(Captain::KnowledgeGaps::Classification).to receive(:new).with(failing_gap)
                                                                  .and_raise(Captain::KnowledgeGaps::Classifier::InvalidOutput)

    expect { task.invoke }.to output(/before: .*unclassified: 2.*classified: 1, failed: 1.*after: .*unanswered: 1.*unclassified: 1/m).to_stdout

    expect(old_gap.occurrences.first).to have_attributes(question: 'do you ship to spain', normalized_question: 'do ship to spain')
    expect(failing_gap.reload).to be_unclassified
  end
end

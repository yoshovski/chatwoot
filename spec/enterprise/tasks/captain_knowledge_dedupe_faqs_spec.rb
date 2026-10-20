require 'rails_helper'
require 'rake'

RSpec.describe 'captain:knowledge:dedupe_generated_faqs' do # rubocop:disable RSpec/DescribeClass
  let(:assistant) { create(:captain_assistant) }
  let(:document) { create(:captain_document, assistant: assistant, content: 'Synthetic') }
  let(:task) do
    unless Rake::Task.task_defined?('captain:knowledge:dedupe_generated_faqs')
      load Rails.root.join('enterprise/lib/tasks/captain_knowledge.rake')
      Rake::Task.define_task(:environment)
    end
    Rake::Task['captain:knowledge:dedupe_generated_faqs']
  end
  let!(:first) { create(:captain_assistant_response, assistant: assistant, documentable: document, origin: 'ai_generated', answer: 'Banner text') }
  let!(:copy) { create(:captain_assistant_response, assistant: assistant, documentable: document, origin: 'ai_generated', answer: ' banner  TEXT ') }
  let!(:edited) do
    create(:captain_assistant_response, assistant: assistant, documentable: document, origin: 'ai_generated', answer: 'Banner text', edited: true)
  end
  let!(:imported) { create(:captain_assistant_response, assistant: assistant, documentable: document, origin: 'page_import', answer: 'Own answer') }

  def run(env)
    with_modified_env({ ACCOUNT_ID: assistant.account_id.to_s, ASSISTANT_ID: assistant.id.to_s }.merge(env)) do
      task.reenable
      expect { task.invoke }.to output.to_stdout
    end
  end

  it 'only lists duplicates on a dry run' do
    run(DRY_RUN: '1')

    expect(Captain::AssistantResponse.where(id: [first.id, copy.id, edited.id, imported.id]).count).to eq(4)
  end

  it 'deletes unedited generated FAQs that repeat another answer and keeps edited and imported ones' do
    run({})

    expect(Captain::AssistantResponse.where(id: [first.id, copy.id, edited.id, imported.id]).pluck(:id)).to contain_exactly(edited.id, imported.id)
  end
end

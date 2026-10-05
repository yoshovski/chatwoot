require 'rails_helper'
require 'rake'

RSpec.describe 'captain:dify:backfill_faqs' do # rubocop:disable RSpec/DescribeClass
  include_context 'with Dify credential encryption'
  let(:account) do
    create(:account, dify_base_url: 'https://dify.example.test', dify_knowledge_api_key: 'private-key',
                     dify_embedding_model: 'example-embedding', dify_embedding_model_provider: 'example/provider')
  end
  let(:assistant) do
    create(:captain_assistant, account: account, config: { dify_faq_dataset_id: 'faq-id', dify_docs_dataset_id: 'docs-id' })
  end
  let(:task) do
    Rails.application.load_tasks unless Rake::Task.task_defined?('captain:dify:backfill_faqs')
    Rake::Task['captain:dify:backfill_faqs']
  end

  it 'can enqueue a backfill twice and stays scoped to the selected assistant' do
    response = create(:captain_assistant_response, assistant: assistant)
    foreign = create(:captain_assistant_response)
    clear_enqueued_jobs

    with_modified_env ASSISTANT_ID: assistant.id.to_s do
      2.times do
        task.reenable
        task.invoke
      end
    end

    expect(Captain::Dify::SyncFaqJob).to have_been_enqueued.with(response.id).exactly(2).times
    expect(Captain::Dify::SyncFaqJob).not_to have_been_enqueued.with(foreign.id)
  end
end

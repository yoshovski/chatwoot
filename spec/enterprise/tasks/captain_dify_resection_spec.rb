require 'rails_helper'
require 'rake'

RSpec.describe 'captain:dify:resection_documents' do # rubocop:disable RSpec/DescribeClass
  include_context 'with Dify credential encryption'
  let(:account) do
    create(:account, dify_base_url: 'https://dify.example.test', dify_knowledge_api_key: 'private-key',
                     dify_embedding_model: 'example-embedding', dify_embedding_model_provider: 'example/provider')
  end
  let(:assistant) do
    create(:captain_assistant, account: account, config: { dify_faq_dataset_id: 'faq-id', dify_docs_dataset_id: 'docs-id' })
  end
  let(:task) do
    Rails.application.load_tasks unless Rake::Task.task_defined?('captain:dify:resection_documents')
    Rake::Task['captain:dify:resection_documents']
  end
  let!(:stale) do
    create(:captain_document, assistant: assistant, content: 'Synthetic', metadata: { dify_document_id: 'a', dify_content_fingerprint: 'old' })
  end
  let!(:current) { create(:captain_document, assistant: assistant, content: 'Synthetic', metadata: { dify_document_id: 'b' }) }
  let!(:unlinked) { create(:captain_document, assistant: assistant, content: 'Synthetic') }

  before do
    current.update!(dify_content_fingerprint: current.dify_source_fingerprint)
    clear_enqueued_jobs
  end

  it 'enqueues only linked documents whose index was built with another fingerprint, and is idempotent' do
    2.times do
      task.reenable
      task.invoke
    end

    expect(Captain::Dify::SyncDocumentJob).to have_been_enqueued.with(stale.id).exactly(2).times
    expect(Captain::Dify::SyncDocumentJob).not_to have_been_enqueued.with(current.id)
    expect(Captain::Dify::SyncDocumentJob).not_to have_been_enqueued.with(unlinked.id)
  end

  it 'can be limited to one account' do
    foreign = create(:captain_document, content: 'Synthetic', metadata: { dify_document_id: 'c', dify_content_fingerprint: 'old' })
    clear_enqueued_jobs

    with_modified_env ACCOUNT_ID: account.id.to_s do
      task.reenable
      task.invoke
    end

    expect(Captain::Dify::SyncDocumentJob).to have_been_enqueued.with(stale.id)
    expect(Captain::Dify::SyncDocumentJob).not_to have_been_enqueued.with(foreign.id)
  end
end

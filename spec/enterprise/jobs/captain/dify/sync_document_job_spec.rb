require 'rails_helper'

RSpec.describe Captain::Dify::SyncDocumentJob do
  include_context 'with Dify credential encryption'

  it 'records missing Dify configuration as a failure without making an OpenAI call' do
    document = create(:captain_document)
    expect(OpenAI::Client).not_to receive(:new)

    described_class.perform_now(document.id)

    expect(document.reload).to be_sync_failed
    expect(document.last_sync_error_code).to eq('dify_not_configured')
    expect(document).to be_in_progress
  end

  it 'only polls again when a retried document was already indexed by Dify' do
    account = create(:account, dify_base_url: 'https://dify.example.test', dify_knowledge_api_key: 'private-key',
                               dify_embedding_model: 'example-embedding', dify_embedding_model_provider: 'example/provider')
    assistant = create(:captain_assistant, account: account, config: { dify_faq_dataset_id: 'faq-id', dify_docs_dataset_id: 'docs-id' })
    document = create(:captain_document, assistant: assistant, content: 'Synthetic text', metadata: { dify_document_id: 'doc-id' })
    document.update!(dify_content_fingerprint: document.dify_source_fingerprint)
    document.mark_dify_sync_failed!('dify_indexing_timeout')
    stub_request(:get, 'https://dify.example.test/v1/datasets/docs-id/documents/doc-id').to_return(body: { indexing_status: 'completed' }.to_json)
    clear_enqueued_jobs

    described_class.perform_now(document.id)

    expect(a_request(:post, %r{/update-by-text})).not_to have_been_made
    expect(Captain::Dify::PollDocumentJob).to have_been_enqueued.with(document.id, 'doc-id', document.dify_source_fingerprint)
  end
end

require 'rails_helper'

RSpec.describe Captain::Dify::RecheckTimedOutDocumentsJob do
  include_context 'with Dify credential encryption'
  let(:account) do
    create(:account, dify_base_url: 'https://dify.example.test', dify_knowledge_api_key: 'private-key',
                     dify_embedding_model: 'example-embedding', dify_embedding_model_provider: 'example/provider')
  end
  let(:assistant) do
    create(:captain_assistant, account: account, config: { dify_faq_dataset_id: 'faq-id', dify_docs_dataset_id: 'docs-id' })
  end
  let(:document) do
    create(:captain_document, assistant: assistant, content: 'Synthetic text', metadata: { dify_document_id: 'doc-id' })
  end
  let(:url) { 'https://dify.example.test/v1/datasets/docs-id/documents/doc-id' }
  let(:state) { { indexing_status: 'completed', enabled: true, archived: false, doc_form: 'hierarchical_model' } }

  before do
    document.mark_dify_sync_failed!('dify_indexing_timeout')
    stub_request(:get, url).to_return(body: state.to_json)
    clear_enqueued_jobs
  end

  it 'marks a timed-out document Ready once Dify has finished indexing it' do
    described_class.perform_now

    expect(document.reload).to be_available
    expect(document).to be_sync_synced
    expect(document.last_sync_error_code).to be_nil
  end

  it 'leaves a document that Dify is still indexing as timed out' do
    stub_request(:get, url).to_return(body: state.merge(indexing_status: 'indexing').to_json)

    described_class.perform_now

    expect(document.reload.last_sync_error_code).to eq('dify_indexing_timeout')
  end

  it 'records an indexing error reported by Dify' do
    stub_request(:get, url).to_return(body: { indexing_status: 'error' }.to_json)

    described_class.perform_now

    expect(document.reload.last_sync_error_code).to eq('dify_indexing_failed')
  end

  it 'does not touch documents that failed for another reason' do
    document.mark_dify_sync_failed!('dify_http_500')

    described_class.perform_now

    expect(a_request(:get, url)).not_to have_been_made
    expect(document.reload.last_sync_error_code).to eq('dify_http_500')
  end

  it 'keeps checking the remaining documents when Dify fails for one of them' do
    other = create(:captain_document, assistant: assistant, content: 'Other text', metadata: { dify_document_id: 'other-id' })
    other.mark_dify_sync_failed!('dify_indexing_timeout')
    stub_request(:get, url).to_return(status: 500)
    stub_request(:get, 'https://dify.example.test/v1/datasets/docs-id/documents/other-id').to_return(body: state.to_json)

    described_class.perform_now

    expect(other.reload).to be_available
  end
end

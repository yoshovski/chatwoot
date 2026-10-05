require 'rails_helper'

RSpec.describe Captain::Dify::DocumentSync do
  include_context 'with Dify credential encryption'
  let(:account) do
    create(:account, dify_base_url: 'https://dify.example.test', dify_knowledge_api_key: 'private-key',
                     dify_embedding_model: 'example-embedding', dify_embedding_model_provider: 'example/provider')
  end
  let(:assistant) do
    create(:captain_assistant, account: account, config: { dify_faq_dataset_id: 'faq-id', dify_docs_dataset_id: 'docs-id' })
  end
  let(:document) { create(:captain_document, assistant: assistant, content: 'First version') }
  let(:fetcher) { instance_double(Captain::Documents::SinglePageFetcher) }
  let(:result) { Captain::Documents::SinglePageFetcher::Result.new(success: true, title: 'Synthetic', content: 'Second version') }

  before do
    allow(Captain::Documents::SinglePageFetcher).to receive(:new).with(document.external_link).and_return(fetcher)
    allow(fetcher).to receive(:fetch).and_return(result)
    document.update!(content_fingerprint: Digest::SHA256.hexdigest(document.content), status: :available,
                     dify_indexing_status: 'completed', dify_document_id: 'doc-id')
    clear_enqueued_jobs
  end

  it 'routes a periodic content change to Dify and waits for indexing before declaring it synced' do
    expect { Captain::Documents::SyncService.new(document).perform }
      .to have_enqueued_job(Captain::Dify::SyncDocumentJob).with(document.id)

    expect(document.reload.content).to eq('Second version')
    expect(document).to be_in_progress
    expect(document).to be_sync_syncing
    expect(document.dify_document_id).to eq('doc-id')
    expect(Captain::Documents::ResponseBuilderJob).not_to have_been_enqueued
  end

  it 'keeps unchanged content pending when its Dify indexing has not finished' do
    result.content = document.content
    document.update!(status: :in_progress, dify_indexing_status: 'indexing')

    expect { Captain::Documents::SyncService.new(document).perform }
      .to have_enqueued_job(Captain::Dify::SyncDocumentJob).with(document.id)
    expect(document.reload).to be_sync_syncing
  end
end

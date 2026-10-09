require 'rails_helper'

RSpec.describe Captain::Dify::Document do
  include_context 'with Dify credential encryption'
  let(:account) do
    create(:account, dify_base_url: 'https://dify.example.test', dify_knowledge_api_key: 'private-key',
                     dify_embedding_model: 'example-embedding', dify_embedding_model_provider: 'example/provider')
  end
  let(:assistant) do
    create(:captain_assistant, account: account, config: { dify_faq_dataset_id: 'faq-id', dify_docs_dataset_id: 'docs-id' })
  end

  it 'keeps a parsed website page pending and sends it to Dify without starting another crawl' do
    document = build(:captain_document, assistant: assistant, content: 'Parsed website content', status: :available)
    clear_enqueued_jobs

    expect { document.save! }.to have_enqueued_job(Captain::Dify::SyncDocumentJob)
    expect(document).to be_in_progress
    expect(document).to be_sync_syncing
    expect(Captain::Documents::CrawlJob).not_to have_been_enqueued
    expect(Captain::Documents::ResponseBuilderJob).not_to have_been_enqueued
  end

  it 'keeps markdown pending until Dify finishes indexing' do
    document = assistant.documents.create!(markdown_content: '# Synthetic markdown', name: 'Synthetic')

    expect(document).to be_markdown_document
    expect(document).to be_in_progress
    expect(Captain::Dify::SyncDocumentJob).to have_been_enqueued.with(document.id)
  end

  it 'invalidates Ready and preserves the previous last-synced time when content changes' do
    document = create(:captain_document, assistant: assistant, content: 'First version')
    previous_sync = 1.day.ago.change(usec: 0)
    document.update!(status: :available, dify_indexing_status: 'completed', last_synced_at: previous_sync)

    document.update!(content: 'Second version', sync_status: :synced, last_synced_at: Time.current)

    expect(document).to be_in_progress
    expect(document).to be_sync_syncing
    expect(document.last_synced_at).to eq(previous_sync)
  end

  it 'deletes a Dify document using server records after its Captain row is gone' do
    document = create(:captain_document, assistant: assistant, content: 'Synthetic')
    document.update!(dify_document_id: 'doc-id')

    expect { document.destroy! }.to have_enqueued_job(Captain::Dify::DeleteDocumentJob).with(document.id, account.id, 'docs-id', 'doc-id')
  end

  it 'captures Dify IDs before deleting an assistant and tolerates its asynchronous child cleanup' do
    document = create(:captain_document, assistant: assistant, content: 'Synthetic', metadata: { dify_document_id: 'doc-id' })
    clear_enqueued_jobs

    expect { assistant.destroy! }.to have_enqueued_job(Captain::Dify::DeleteDocumentJob).with(document.id, account.id, 'docs-id', 'doc-id')
    expect { document.reload.destroy! }.not_to raise_error
  end

  it 'enqueues Dify status update with disable when paused, and enable when resumed' do
    document = create(:captain_document, assistant: assistant, content: 'Synthetic', metadata: { dify_document_id: 'doc-id' })
    clear_enqueued_jobs

    expect { document.update!(enabled: false) }.to have_enqueued_job(Captain::Dify::UpdateDocumentStatusJob)
      .with(account.id, 'docs-id', 'disable', ['doc-id'])

    clear_enqueued_jobs

    expect { document.update!(enabled: true) }.to have_enqueued_job(Captain::Dify::UpdateDocumentStatusJob)
      .with(account.id, 'docs-id', 'enable', ['doc-id'])
  end

  describe '#dify_source_fingerprint' do
    it 'is versioned for text documents and follows the sectioned text' do
      document = create(:captain_document, assistant: assistant, content: '## Returns\n\nBody')

      expect(document.dify_source_fingerprint).to eq("sectioned-v1:#{Digest::SHA256.hexdigest(document.dify_sectioned_content)}")
    end

    it 'changes when the document title changes' do
      document = create(:captain_document, assistant: assistant, content: 'Body', name: 'First title')
      before = document.dify_source_fingerprint

      document.name = 'Second title'

      expect(document.dify_source_fingerprint).not_to eq(before)
    end
  end

  describe '#knowledge_state' do
    let(:document) { create(:captain_document, assistant: assistant, content: 'Body') }

    it 'is nil when the account does not use Dify' do
      plain = create(:captain_document, content: 'Body')

      expect(plain.knowledge_state).to be_nil
    end

    it 'is paused when the document is disabled, even if it is indexed' do
      document.update!(status: :available, dify_indexing_status: 'completed', enabled: false)

      expect(document.knowledge_state).to eq('paused')
    end

    it 'is searchable once the page is available and Dify finished indexing it' do
      document.update!(status: :available, dify_indexing_status: 'completed')

      expect(document.knowledge_state).to eq('searchable')
    end

    it 'is indexing while Dify is still working on it' do
      expect(document.knowledge_state).to eq('indexing')
    end

    it 'is not searchable when Dify reported an indexing error' do
      document.update!(dify_indexing_status: 'error')

      expect(document.knowledge_state).to eq('not_searchable')
    end

    it 'is not searchable when the sync failed and there is no completed index' do
      document.update!(sync_status: :failed, dify_indexing_status: 'waiting')

      expect(document.knowledge_state).to eq('not_searchable')
    end

    it 'stays searchable when only a later re-fetch failed and the earlier index is complete' do
      document.update!(status: :available, dify_indexing_status: 'completed', sync_status: :failed)

      expect(document.knowledge_state).to eq('searchable')
    end
  end
end

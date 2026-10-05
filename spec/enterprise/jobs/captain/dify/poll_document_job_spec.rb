require 'rails_helper'

RSpec.describe Captain::Dify::PollDocumentJob do
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
  let(:state) { { indexing_status: 'completed', enabled: true, archived: false, doc_form: 'hierarchical_model' } }
  let(:url) { 'https://dify.example.test/v1/datasets/docs-id/documents/doc-id' }

  before do
    stub_request(:get, url).to_return(body: state.to_json)
    document.update!(dify_content_fingerprint: document.dify_source_fingerprint)
    clear_enqueued_jobs
  end

  it 'marks a completed document Ready and generates website FAQs exactly once after committing' do
    2.times { described_class.perform_now(document.id, 'doc-id', document.dify_source_fingerprint) }

    expect(document.reload).to be_available
    expect(document).to be_sync_synced
    expect(Captain::Documents::ResponseBuilderJob).to have_been_enqueued.with(document).once
  end

  it 'keeps an indexing document pending and schedules another poll' do
    state[:indexing_status] = 'indexing'
    stub_request(:get, url).to_return(body: state.to_json)

    described_class.perform_now(document.id, 'doc-id', document.dify_source_fingerprint)

    expect(document.reload).to be_in_progress
    expect(described_class).to have_been_enqueued.with(document.id, 'doc-id', document.dify_source_fingerprint, 1)
    expect(Captain::Documents::ResponseBuilderJob).not_to have_been_enqueued
  end

  it 'does not mark newer content Ready from a stale polling result' do
    old_fingerprint = document.dify_source_fingerprint
    document.update!(content: 'Newer content')

    described_class.perform_now(document.id, 'doc-id', old_fingerprint)

    expect(document.reload).to be_in_progress
    expect(Captain::Documents::ResponseBuilderJob).not_to have_been_enqueued
  end

  it 'records indexing failure without storing the private Dify error message' do
    stub_request(:get, url).to_return(body: { indexing_status: 'error', error: 'private provider response' }.to_json)

    described_class.perform_now(document.id, 'doc-id', document.dify_source_fingerprint)

    expect(document.reload).to be_sync_failed
    expect(document.last_sync_error_code).to eq('dify_indexing_failed')
    expect(document).to be_in_progress
  end

  it 'bounds polling and marks a timeout as failed' do
    stub_request(:get, url).to_return(body: { indexing_status: 'indexing' }.to_json)

    described_class.perform_now(document.id, 'doc-id', document.dify_source_fingerprint, described_class::MAX_POLLS)

    expect(document.reload.last_sync_error_code).to eq('dify_indexing_timeout')
    expect(described_class).not_to have_been_enqueued
  end

  it 'marks a PDF Ready without generating FAQs or retaining an OpenAI upload' do
    pdf = assistant.documents.new(name: 'Synthetic PDF')
    pdf.pdf_file.attach(io: StringIO.new('%PDF-1.4 synthetic'), filename: 'synthetic.pdf', content_type: 'application/pdf')
    pdf.save!
    pdf.update!(dify_document_id: 'doc-id', dify_content_fingerprint: pdf.dify_source_fingerprint)
    clear_enqueued_jobs

    described_class.perform_now(pdf.id, 'doc-id', pdf.dify_source_fingerprint)

    expect(pdf.reload).to be_available
    expect(pdf.openai_file_id).to be_nil
    expect(Captain::Documents::ResponseBuilderJob).not_to have_been_enqueued
  end
end

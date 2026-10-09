require 'rails_helper'

RSpec.describe Captain::Dify::DocumentSyncService do
  include_context 'with Dify credential encryption'
  let(:account) do
    create(:account, dify_base_url: 'https://dify.example.test', dify_knowledge_api_key: 'private-key',
                     dify_embedding_model: 'example-embedding', dify_embedding_model_provider: 'example/provider')
  end
  let(:assistant) do
    create(:captain_assistant, account: account, config: { dify_faq_dataset_id: 'faq-id', dify_docs_dataset_id: 'docs-id' })
  end
  let(:document) { create(:captain_document, assistant: assistant, content: 'Synthetic website text', status: :available) }
  let(:client) { instance_double(Dify::KnowledgeClient) }
  let(:result) { { 'document' => { 'id' => 'doc-id', 'indexing_status' => 'waiting' } } }

  before do
    allow(document.account).to receive(:dify_knowledge_client).and_return(client)
    allow(client).to receive(:documents).and_return('data' => [])
    allow(client).to receive(:create_by_text).and_return(result)
    allow(client).to receive(:create_by_file).and_return(result)
    allow(client).to receive(:document).and_return('indexing_status' => 'completed')
    allow(client).to receive(:update_by_text).and_return(result)
  end

  it 'creates parent-child text ingestion and keeps Captain pending for the polling job' do
    expect(described_class.new(document).perform).to eq(['doc-id', document.dify_source_fingerprint])

    expect(document.reload.dify_document_id).to eq('doc-id')
    expect(document).to be_in_progress
    expect(client).to have_received(:create_by_text).with(hash_including(dataset_id: 'docs-id', doc_form: 'hierarchical_model'))
  end

  it 'sends the section-aware text instead of the raw content' do
    document.update!(content: "## Returns\n\nItems must be unused.")

    described_class.new(document).perform

    expect(client).to have_received(:create_by_text).with(hash_including(text: "#{document.name} > Returns\nItems must be unused."))
  end

  it 'updates a linked document in place when its content fingerprint changes' do
    document.update!(dify_document_id: 'doc-id', dify_content_fingerprint: 'old-fingerprint')

    described_class.new(document).perform

    expect(client).to have_received(:update_by_text).with(hash_including(document_id: 'doc-id', text: document.dify_sectioned_content))
    expect(client).not_to have_received(:create_by_text)
  end

  it 'reuses a completed unchanged document on a repeated backfill' do
    service = described_class.new(document)
    service.perform
    document.update!(status: :available, dify_indexing_status: 'completed')

    expect(service.perform).to be_nil
    expect(client).to have_received(:create_by_text).once
    expect(client).not_to have_received(:update_by_text)
  end

  it 'recovers an interrupted create and then sends the current content before marking it indexed' do
    allow(client).to receive(:documents).and_return('data' => [{ 'id' => 'doc-id', 'name' => "Captain Document #{document.id}." }])

    described_class.new(document).perform

    expect(client).not_to have_received(:create_by_text)
    expect(client).to have_received(:update_by_text)
  end

  it 'uploads the attached PDF directly to Dify with parent-child processing' do
    pdf = assistant.documents.new(name: 'Synthetic PDF')
    pdf.pdf_file.attach(io: StringIO.new('%PDF-1.4 synthetic'), filename: 'synthetic.pdf', content_type: 'application/pdf')
    pdf.save!
    allow(pdf.account).to receive(:dify_knowledge_client).and_return(client)

    described_class.new(pdf).perform

    expect(client).to have_received(:create_by_file).with(hash_including(dataset_id: 'docs-id', filename: 'synthetic.pdf',
                                                                         content_type: 'application/pdf', doc_form: 'hierarchical_model'))
    expect(client).not_to have_received(:create_by_text)
    expect(pdf.reload.openai_file_id).to be_nil
  end
end

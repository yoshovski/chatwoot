require 'rails_helper'

RSpec.describe Captain::Dify::FaqSyncService do
  include_context 'with Dify credential encryption'
  let(:account) do
    create(:account, dify_base_url: 'https://dify.example.test', dify_knowledge_api_key: 'private-key',
                     dify_embedding_model: 'example-embedding', dify_embedding_model_provider: 'example/provider')
  end
  let(:assistant) do
    create(:captain_assistant, account: account, config: { dify_faq_dataset_id: 'faq-id', dify_docs_dataset_id: 'docs-id' })
  end
  let(:response) { create(:captain_assistant_response, assistant: assistant, embedding: nil) }
  let(:client) { instance_double(Dify::KnowledgeClient) }
  let(:content) { response.question }
  let(:completed) { { 'id' => 'chunk-id', 'content' => content, 'answer' => response.answer, 'enabled' => true, 'status' => 'completed' } }

  before do
    allow(account).to receive(:dify_knowledge_client).and_return(client)
    allow(client).to receive(:documents).and_return('data' => [])
    allow(client).to receive(:create_by_text).and_return('document' => { 'id' => 'doc-id' })
    allow(client).to receive(:document).and_return('doc_form' => 'qa_model', 'indexing_status' => 'completed')
    allow(client).to receive(:segments).and_return('total' => 1, 'data' => [{ 'id' => 'chunk-id', 'content' => 'placeholder' }])
    allow(client).to receive(:update_segment) do |**attributes|
      { 'data' => completed.merge('content' => attributes.fetch(:content), 'answer' => attributes.fetch(:answer)) }
    end
  end

  it 'persists the document ID across an indexing retry and then writes the exact question and answer' do
    allow(client).to receive(:document).and_return({ 'doc_form' => 'qa_model', 'indexing_status' => 'indexing' },
                                                   { 'doc_form' => 'qa_model', 'indexing_status' => 'completed' })
    service = described_class.new(response)

    expect { service.perform }.to raise_error(described_class::IndexingPending)
    expect(response.reload.dify_document_id).to eq('doc-id')
    service.perform

    expect(client).to have_received(:create_by_text).once
    expect(client).to have_received(:update_segment).with(dataset_id: 'faq-id', document_id: 'doc-id', segment_id: 'chunk-id',
                                                          content: content, answer: response.answer, enabled: true).once
  end

  it 'recovers a document created before its HTTP response was lost' do
    allow(client).to receive(:documents).and_return('data' => [{ 'id' => 'recovered-id', 'name' => "Captain FAQ #{response.id}." }])

    described_class.new(response).perform

    expect(response.reload.dify_document_id).to eq('recovered-id')
    expect(client).not_to have_received(:create_by_text)
  end

  it 'preserves long answers and whitespace exactly without feeding the FAQ to the text splitter' do
    response.update!(question: 'Question?  ', answer: "  First line\n\n#{'abc ' * 4900}\nLast line  ")

    described_class.new(response).perform

    expect(client).to have_received(:create_by_text).with(hash_including(doc_form: 'qa_model'))
    expect(client).to have_received(:update_segment).with(hash_including(content: content, answer: response.answer))
  end

  it 'can run a backfill twice without duplicating documents or reindexing unchanged completed chunks' do
    service = described_class.new(response)
    service.perform
    allow(client).to receive(:segments).and_return('total' => 1, 'data' => [completed])
    service.perform

    expect(client).to have_received(:create_by_text).once
    expect(client).to have_received(:update_segment).once
  end

  it 'updates a linked FAQ in place and retries a chunk Dify returned as disabled' do
    response.update!(dify_document_id: 'doc-id')
    allow(client).to receive(:update_segment).and_return('data' => completed.merge('enabled' => false, 'status' => 'error'))

    expect { described_class.new(response).perform }.to raise_error(Dify::KnowledgeClient::Error, 'Dify FAQ chunk indexing failed')
    expect(response.reload.dify_document_id).to eq('doc-id')
    expect(client).not_to have_received(:create_by_text)
  end

  it 'replaces multiple generated staging chunks with a single exact source pair' do
    allow(client).to receive(:segments).and_return({ 'total' => 2, 'data' => [{ 'id' => 'seed-one' }, { 'id' => 'seed-two' }] },
                                                   { 'total' => 0, 'data' => [] })
    allow(client).to receive(:delete_segment)
    allow(client).to receive(:create_segments).and_return('data' => [completed])

    described_class.new(response).perform

    expect(client).to have_received(:delete_segment).twice
    expect(client).to have_received(:create_segments).with(dataset_id: 'faq-id', document_id: 'doc-id',
                                                           segments: [{ content: response.question, answer: response.answer }])
    expect(response.reload.dify_document_id).to eq('doc-id')
    expect(client).not_to have_received(:update_segment)
  end
end

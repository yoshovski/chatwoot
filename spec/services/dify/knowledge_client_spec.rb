require 'rails_helper'

RSpec.describe Dify::KnowledgeClient do
  let(:client) { described_class.new(base_url: 'https://dify.example.test', api_key: 'private-test-key') }
  let(:root) { 'https://dify.example.test/v1/datasets' }

  it 'creates datasets and text documents with authenticated JSON requests' do
    create = stub_request(:post, root).with(headers: { 'Authorization' => 'Bearer private-test-key' }, body: { name: 'FAQs' })
                                      .to_return(body: '{"id":"dataset-one"}')
    text = stub_request(:post, "#{root}/dataset-one/document/create-by-text").with(body: { name: 'Question', text: 'Answer' })
                                                                             .to_return(body: '{"document":{"id":"doc-one"}}')

    expect(client.create_dataset(name: 'FAQs')).to eq('id' => 'dataset-one')
    expect(client.create_by_text(dataset_id: 'dataset-one', name: 'Question', text: 'Answer')).to eq('document' => { 'id' => 'doc-one' })
    expect(create).to have_been_requested.once
    expect(text).to have_been_requested.once
  end

  it 'uploads files as multipart with the document processing configuration' do
    upload = stub_request(:post, "#{root}/dataset-one/document/create-by-file")
             .with { |request| request.body.include?('hierarchical_model') && request.body.include?('synthetic document') }
             .to_return(body: '{"batch":"batch-one"}')

    result = client.create_by_file(dataset_id: 'dataset-one', file: StringIO.new('synthetic document'),
                                   filename: 'example.txt', content_type: 'text/plain', doc_form: 'hierarchical_model')

    expect(result).to eq('batch' => 'batch-one')
    expect(upload).to have_been_requested.once
  end

  it 'updates text, checks indexing and accepts an empty delete response' do
    stub_request(:post,
                 "#{root}/dataset-one/documents/doc-one/update-by-text").with(body: { text: 'Updated' }).to_return(body: '{"batch":"batch-two"}')
    stub_request(:get, "#{root}/dataset-one/documents/batch-two/indexing-status").to_return(body: '{"data":[{"indexing_status":"completed"}]}')
    stub_request(:delete, "#{root}/dataset-one/documents/doc-one").to_return(status: 204)

    expect(client.update_by_text(dataset_id: 'dataset-one', document_id: 'doc-one', text: 'Updated')).to eq('batch' => 'batch-two')
    expect(client.indexing_status(dataset_id: 'dataset-one', batch: 'batch-two')['data'].first['indexing_status']).to eq('completed')
    expect(client.delete_document(dataset_id: 'dataset-one', document_id: 'doc-one')).to be_nil
  end

  it 'updates document status with PATCH request' do
    patch_req = stub_request(:patch, "#{root}/dataset-one/documents/status/disable")
                .with(body: { document_ids: %w[doc-one doc-two] })
                .to_return(body: '{"result":"success"}')

    expect(client.update_documents_status(dataset_id: 'dataset-one', action: 'disable', document_ids: %w[doc-one doc-two]))
      .to eq('result' => 'success')
    expect(patch_req).to have_been_requested.once
  end

  it 'passes hybrid search, reranking and metadata conditions to retrieval' do
    model = { search_method: 'hybrid_search', reranking_enable: true, metadata_filtering_conditions: { conditions: [] } }
    retrieval = stub_request(:post, "#{root}/dataset-one/retrieve").with(body: { query: 'Example', retrieval_model: model })
                                                                   .to_return(body: '{"records":[]}')

    expect(client.retrieve(dataset_id: 'dataset-one', query: 'Example', retrieval_model: model)).to eq('records' => [])
    expect(retrieval).to have_been_requested.once
  end

  it 'finds documents and replaces a native chunk without invoking the text splitter' do
    stub_request(:get, "#{root}/dataset-one/documents").with(query: { keyword: 'Captain FAQ 1.', limit: 2 })
                                                       .to_return(body: '{"data":[{"id":"doc-one"}]}')
    stub_request(:get, "#{root}/dataset-one/documents/doc-one").to_return(body: '{"indexing_status":"completed"}')
    stub_request(:get, "#{root}/dataset-one/documents/doc-one/segments").with(query: { limit: 2 })
                                                                        .to_return(body: '{"data":[{"id":"chunk-one"}],"total":1}')
    update = stub_request(:post, "#{root}/dataset-one/documents/doc-one/segments/chunk-one")
             .with(body: { segment: { content: "question: Example\nanswer: Exact answer", enabled: true } })
             .to_return(body: '{"data":{"id":"chunk-one"}}')

    expect(client.documents(dataset_id: 'dataset-one', keyword: 'Captain FAQ 1.')['data'].first['id']).to eq('doc-one')
    expect(client.document(dataset_id: 'dataset-one', document_id: 'doc-one')['indexing_status']).to eq('completed')
    expect(client.segments(dataset_id: 'dataset-one', document_id: 'doc-one')['total']).to eq(1)
    expect(client.update_segment(dataset_id: 'dataset-one', document_id: 'doc-one', segment_id: 'chunk-one',
                                 content: "question: Example\nanswer: Exact answer", enabled: true)['data']['id']).to eq('chunk-one')
    expect(update).to have_been_requested.once
  end

  it 'preserves an inaccessible dataset status without exposing the server response' do
    stub_request(:get, "#{root}/foreign-dataset").to_return(status: 404, body: 'private-test-key client content')

    expect { client.dataset('foreign-dataset') }.to raise_error(described_class::Error, 'Dify request failed (HTTP 404)') { |error|
      expect(error.status).to eq(404)
    }
  end

  it 'retries safe reads but never repeats a dataset creation on server failure' do
    read = stub_request(:get, "#{root}/dataset-one").to_return(status: 503).then.to_return(body: '{"id":"dataset-one"}')
    create = stub_request(:post, root).to_return(status: 503)

    expect(client.dataset('dataset-one')).to eq('id' => 'dataset-one')
    expect { client.create_dataset(name: 'FAQs') }.to raise_error(described_class::Error)
    expect(read).to have_been_requested.twice
    expect(create).to have_been_requested.once
  end
end

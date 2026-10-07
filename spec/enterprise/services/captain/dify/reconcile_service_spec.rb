require 'rails_helper'

RSpec.describe Captain::Dify::ReconcileService do
  include_context 'with Dify credential encryption'
  let(:account) do
    create(:account, dify_base_url: 'https://dify.example.test', dify_knowledge_api_key: 'private-key',
                     dify_embedding_model: 'example-embedding', dify_embedding_model_provider: 'example/provider')
  end
  let(:assistant) do
    create(:captain_assistant, account: account).tap do |assistant|
      assistant.update!(config: assistant.config.merge('dify_faq_dataset_id' => 'faq-ds', 'dify_docs_dataset_id' => 'docs-ds'))
    end
  end
  let(:client) { instance_double(Dify::KnowledgeClient) }
  let!(:kept_document) { create(:captain_document, assistant: assistant, account: account, metadata: { 'dify_document_id' => 'kept-doc' }) }
  let!(:lost_document) { create(:captain_document, assistant: assistant, account: account, metadata: { 'dify_document_id' => 'lost-doc' }) }
  let!(:kept_faq) { create(:captain_assistant_response, assistant: assistant, account: account, dify_document_id: 'kept-faq') }
  let!(:lost_faq) { create(:captain_assistant_response, assistant: assistant, account: account, dify_document_id: 'lost-faq') }

  before do
    allow(account).to receive(:dify_knowledge_client).and_return(client)
    allow(client).to receive(:documents).with(dataset_id: 'docs-ds', keyword: '', page: 1, limit: 100)
                                        .and_return('data' => [{ 'id' => 'kept-doc' }], 'has_more' => true)
    allow(client).to receive(:documents).with(dataset_id: 'docs-ds', keyword: '', page: 2, limit: 100)
                                        .and_return('data' => [{ 'id' => 'other-doc' }], 'has_more' => false)
    allow(client).to receive(:documents).with(dataset_id: 'faq-ds', keyword: '', page: 1, limit: 100)
                                        .and_return('data' => [{ 'id' => 'kept-faq' }], 'has_more' => false)
  end

  it 'clears and re-syncs only the records whose Dify document is gone' do
    result = nil

    expect { result = described_class.new(assistant).perform }
      .to have_enqueued_job(Captain::Dify::SyncDocumentJob).with(lost_document.id).exactly(:once)
      .and have_enqueued_job(Captain::Dify::SyncFaqJob).with(lost_faq.id).exactly(:once)

    expect(result).to eq(documents: 1, faqs: 1)
    expect(lost_document.reload.dify_document_id).to be_nil
    expect(lost_faq.reload.dify_document_id).to be_nil
    expect(kept_document.reload.dify_document_id).to eq('kept-doc')
    expect(kept_faq.reload.dify_document_id).to eq('kept-faq')
  end
end

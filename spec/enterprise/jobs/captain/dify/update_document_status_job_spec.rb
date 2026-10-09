require 'rails_helper'

RSpec.describe Captain::Dify::UpdateDocumentStatusJob do
  let(:account) { create(:account) }
  let(:client) { instance_double(Dify::KnowledgeClient) }

  before do
    allow(Account).to receive(:find).with(account.id).and_return(account)
    allow(account).to receive(:dify_knowledge_enabled?).and_return(true)
    allow(account).to receive(:dify_knowledge_client).and_return(client)
  end

  it 'updates status on Dify dataset' do
    expect(client).to receive(:update_documents_status).with(
      dataset_id: 'dataset-123',
      action: 'disable',
      document_ids: %w[dify-doc-1 dify-doc-2]
    )

    described_class.perform_now(account.id, 'dataset-123', 'disable', %w[dify-doc-1 dify-doc-2])
  end

  it 'treats an already missing document (404) as success' do
    allow(client).to receive(:update_documents_status).and_raise(
      Dify::KnowledgeClient::Error.new('Dify request failed (HTTP 404)', status: 404)
    )

    expect do
      described_class.perform_now(account.id, 'dataset-123', 'disable', ['dify-doc-1'])
    end.not_to raise_error
  end

  it 'does nothing if document_ids is blank' do
    expect(client).not_to receive(:update_documents_status)

    described_class.perform_now(account.id, 'dataset-123', 'disable', [])
  end

  it 'does nothing if account does not have dify knowledge enabled' do
    allow(account).to receive(:dify_knowledge_enabled?).and_return(false)
    expect(client).not_to receive(:update_documents_status)

    described_class.perform_now(account.id, 'dataset-123', 'disable', ['dify-doc-1'])
  end
end

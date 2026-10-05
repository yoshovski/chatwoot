require 'rails_helper'

RSpec.describe Captain::Dify::DeleteFaqJob do
  let(:account) { create(:account) }
  let(:client) { instance_double(Dify::KnowledgeClient) }

  before do
    allow(Account).to receive(:find).with(account.id).and_return(account)
    allow(account).to receive(:dify_knowledge_client).and_return(client)
  end

  it 'deletes using server-captured IDs after the FAQ row has been destroyed' do
    expect(client).to receive(:delete_document).with(dataset_id: 'faq-id', document_id: 'doc-id')

    described_class.perform_now(123, account.id, 'faq-id', 'doc-id')
  end

  it 'treats an already deleted document as success' do
    allow(client).to receive(:delete_document).and_raise(Dify::KnowledgeClient::Error.new('Dify request failed (HTTP 404)', status: 404))

    expect { described_class.perform_now(123, account.id, 'faq-id', 'doc-id') }.not_to raise_error
    expect(described_class).not_to have_been_enqueued
  end
end

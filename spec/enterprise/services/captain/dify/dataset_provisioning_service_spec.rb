require 'rails_helper'

RSpec.describe Captain::Dify::DatasetProvisioningService do
  include_context 'with Dify credential encryption'
  let(:account) do
    create(:account, dify_base_url: 'https://dify.example.test', dify_knowledge_api_key: 'private-key',
                     dify_embedding_model: 'example-embedding', dify_embedding_model_provider: 'example/provider')
  end
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:client) { instance_double(Dify::KnowledgeClient) }

  before do
    allow(account).to receive(:dify_knowledge_client).and_return(client)
  end

  it 'creates both assistant datasets once with the account embedding model' do
    allow(client).to receive(:create_dataset).with(
      name: "Captain #{assistant.id} FAQs", indexing_technique: 'high_quality', permission: 'only_me',
      embedding_model: 'example-embedding', embedding_model_provider: 'example/provider'
    ).and_return('id' => 'faq-id')
    allow(client).to receive(:create_dataset).with(
      name: "Captain #{assistant.id} Documents", indexing_technique: 'high_quality', permission: 'only_me',
      embedding_model: 'example-embedding', embedding_model_provider: 'example/provider'
    ).and_return('id' => 'docs-id')

    2.times { described_class.new(assistant).perform }

    expect(assistant.reload.config).to include('dify_faq_dataset_id' => 'faq-id', 'dify_docs_dataset_id' => 'docs-id')
    expect(assistant.client_config).not_to include('dify_faq_dataset_id', 'dify_docs_dataset_id')
    expect(client).to have_received(:create_dataset).twice
  end

  it 'preserves the first dataset ID if creating the second fails' do
    allow(client).to receive(:create_dataset).and_return('id' => 'faq-id').once
    allow(client).to receive(:create_dataset).with(hash_including(name: "Captain #{assistant.id} Documents"))
                                             .and_raise(Dify::KnowledgeClient::Error, 'Dify request failed')

    expect { described_class.new(assistant).perform }.to raise_error(Dify::KnowledgeClient::Error)
    expect(assistant.reload.config['dify_faq_dataset_id']).to eq('faq-id')
    expect(assistant.config['dify_docs_dataset_id']).to be_nil
  end

  it 'rejects extra datasets outside the account workspace before persisting them' do
    allow(client).to receive(:dataset).with('foreign-id').and_raise(Dify::KnowledgeClient::Error.new('Dify request failed (HTTP 404)', status: 404))

    expect { assistant.dify_extra_dataset_ids = ['foreign-id'] }.to raise_error(Dify::KnowledgeClient::Error)
    expect(assistant.config).not_to have_key('dify_extra_dataset_ids')
  end
end

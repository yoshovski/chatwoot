require 'rails_helper'

RSpec.describe Captain::Dify::DescribeDatasetsJob do
  include_context 'with Dify credential encryption'
  let(:account) do
    create(:account, name: 'Acme', dify_base_url: 'https://dify.example.test', dify_knowledge_api_key: 'private-key',
                     dify_embedding_model: 'example-embedding', dify_embedding_model_provider: 'example/provider')
  end
  let(:assistant) do
    create(:captain_assistant, account: account, name: 'Octave',
                               config: { 'dify_faq_dataset_id' => 'faq-id', 'dify_docs_dataset_id' => 'docs-id' })
  end
  let(:client) { instance_double(Dify::KnowledgeClient) }

  before do
    allow(Captain::Assistant).to receive(:find_by).with(id: assistant.id).and_return(assistant)
    allow(assistant.account).to receive(:dify_knowledge_client).and_return(client)
  end

  it 'updates the name and description of both datasets and skips one that no longer exists' do
    allow(client).to receive(:update_dataset).with('faq-id', hash_including(name: "##{account.id} Acme · Octave · FAQs"))
    allow(client).to receive(:update_dataset).with('docs-id', anything)
                                             .and_raise(Dify::KnowledgeClient::Error.new('Dify request failed (HTTP 404)', status: 404))

    described_class.perform_now(assistant.id)

    expect(client).to have_received(:update_dataset).twice
  end

  it 'refreshes the names when the agent is renamed' do
    expect { assistant.update!(name: 'Luna') }.to have_enqueued_job(described_class).with(assistant.id)
  end

  it 'refreshes the names when the account is renamed' do
    assistant
    expect { account.update!(name: 'Acme Drones') }.to have_enqueued_job(described_class).with(assistant.id)
  end
end

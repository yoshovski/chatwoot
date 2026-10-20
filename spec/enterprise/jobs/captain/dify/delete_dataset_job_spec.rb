require 'rails_helper'

RSpec.describe Captain::Dify::DeleteDatasetJob do
  include_context 'with Dify credential encryption'
  let(:account) do
    create(:account, dify_base_url: 'https://dify.example.test', dify_knowledge_api_key: 'private-key',
                     dify_embedding_model: 'example-embedding', dify_embedding_model_provider: 'example/provider')
  end
  let(:url) { 'https://dify.example.test/v1/datasets/old-id' }

  it 'deletes a dataset no agent uses and treats a missing one as deleted' do
    stub_request(:delete, url).to_return(status: 404)

    expect { described_class.perform_now(account.id, 'old-id') }.not_to raise_error
    expect(a_request(:delete, url)).to have_been_made
  end

  it 'keeps a dataset that another agent uses as an extra dataset' do
    create(:captain_assistant, account: account, config: { dify_extra_dataset_ids: ['old-id'] })

    described_class.perform_now(account.id, 'old-id')

    expect(a_request(:delete, url)).not_to have_been_made
  end

  it 'is queued for both datasets when an agent is deleted' do
    assistant = create(:captain_assistant, account: account, config: { dify_faq_dataset_id: 'faq-id', dify_docs_dataset_id: 'docs-id' })
    clear_enqueued_jobs

    assistant.destroy!

    expect(described_class).to have_been_enqueued.with(account.id, 'faq-id')
    expect(described_class).to have_been_enqueued.with(account.id, 'docs-id')
  end
end

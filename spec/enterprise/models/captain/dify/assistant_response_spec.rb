require 'rails_helper'

RSpec.describe Captain::Dify::AssistantResponse, type: :model do
  include_context 'with Dify credential encryption'
  let(:account) do
    create(:account, dify_base_url: 'https://dify.example.test', dify_knowledge_api_key: 'private-key',
                     dify_embedding_model: 'example-embedding', dify_embedding_model_provider: 'example/provider')
  end
  let(:assistant) { create(:captain_assistant, account: account, config: { dify_faq_dataset_id: 'faq-id' }) }
  let(:response) { create(:captain_assistant_response, assistant: assistant, embedding: nil) }

  it 'syncs creations and wording edits without scheduling embeddings' do
    expect { response }.to have_enqueued_job(Captain::Dify::SyncFaqJob)
    clear_enqueued_jobs
    expect { response.update!(answer: 'Revised answer') }.to have_enqueued_job(Captain::Dify::SyncFaqJob).with(response.id)
    expect(Captain::Llm::UpdateEmbeddingJob).not_to have_been_enqueued
  end

  it 'does not resync an unrelated change on an already linked FAQ' do
    response.update!(dify_document_id: 'doc-id')
    clear_enqueued_jobs

    expect { response.update!(edited: false) }.not_to have_enqueued_job(Captain::Dify::SyncFaqJob)
  end

  it 'deletes the linked document after destroying the FAQ' do
    response.update!(dify_document_id: 'doc-id')
    clear_enqueued_jobs

    expect { response.destroy! }.to have_enqueued_job(Captain::Dify::DeleteFaqJob).with(response.id, account.id, 'faq-id', 'doc-id')
    expect(Captain::Dify::SyncFaqJob).not_to have_been_enqueued
    expect(Captain::Llm::UpdateEmbeddingJob).not_to have_been_enqueued
  end

  it 'moves a FAQ between assistant datasets without reusing the old document ID' do
    destination = create(:captain_assistant, account: account, config: { dify_faq_dataset_id: 'destination-id' })
    response.update!(dify_document_id: 'doc-id')
    clear_enqueued_jobs

    response.update!(assistant: destination)

    expect(response.reload.dify_document_id).to be_nil
    expect(Captain::Dify::DeleteFaqJob).to have_been_enqueued.with(response.id, account.id, 'faq-id', 'doc-id')
    expect(Captain::Dify::SyncFaqJob).to have_been_enqueued.with(response.id)
  end

  it 'captures cleanup IDs before deleting an assistant whose FAQ rows are destroyed asynchronously' do
    response.update!(dify_document_id: 'doc-id')
    clear_enqueued_jobs

    expect { assistant.destroy! }.to have_enqueued_job(Captain::Dify::DeleteFaqJob).with(response.id, account.id, 'faq-id', 'doc-id')
    response.reload.destroy!
  end

  it 'does not enqueue embeddings or Dify writes for an unconfigured account' do
    expect { create(:captain_assistant_response, embedding: nil) }.not_to have_enqueued_job(Captain::Dify::SyncFaqJob)
    expect(Captain::Llm::UpdateEmbeddingJob).not_to have_been_enqueued
  end

  it 'does not enqueue embedding jobs for FAQ suggestions' do
    suggestion = Captain::FaqSuggestion.create!(assistant: assistant, question: 'Suggestion?', answer: 'Suggested answer')
    suggestion.update!(answer: 'Edited suggestion')

    expect(Captain::Llm::UpdateEmbeddingJob).not_to have_been_enqueued
  end
end

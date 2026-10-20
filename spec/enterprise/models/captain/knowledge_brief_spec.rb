require 'rails_helper'

RSpec.describe Captain::KnowledgeBrief do
  let(:assistant) { create(:captain_assistant, config: { 'knowledge_brief_enabled' => true }) }
  let(:document) { create(:captain_document, assistant: assistant, account: assistant.account, status: :available, content: 'About us') }
  let(:brief) do
    assistant.create_knowledge_brief!(account: assistant.account, status: 'ready').tap do |record|
      snapshot = { 'overview' => { 'text' => 'We sell subscriptions.', 'document_ids' => [document.id] }, 'topics' => [],
                   'document_ids' => [document.id], 'revision' => 'r1' }
      record.update!(published: snapshot.merge('source_fingerprint' => record.fingerprint([document.id])))
    end
  end

  it 'keeps the approved text in use after its sources change and flags it for review' do
    brief
    document.update!(content: 'About us, updated')

    expect(brief.reload.prompt_context[:business_overview]).to include('text' => 'We sell subscriptions.')
    expect(brief.client_payload).to include('published_usable' => true, 'sources_changed' => true)
  end

  it 'stops using it when a source is disabled or made private' do
    brief
    document.update!(agents_only: true)

    expect(brief.reload.prompt_context).to eq({})
  end
end

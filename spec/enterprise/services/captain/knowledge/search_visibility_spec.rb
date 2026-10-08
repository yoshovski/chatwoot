require 'rails_helper'

RSpec.describe Captain::Knowledge::Search do
  let(:account) { create(:account) }
  let(:assistant) do
    create(:captain_assistant, account: account, config: { 'dify_faq_dataset_id' => 'faq-ds', 'dify_docs_dataset_id' => 'docs-ds' })
  end
  let(:public_document) { create(:captain_document, assistant: assistant, account: account, status: :available) }
  let(:internal_document) { create(:captain_document, assistant: assistant, account: account, status: :available, agents_only: true) }
  let(:knowledge_client) { instance_double(AiAgents::KnowledgeClient) }

  def passage(kind, dataset_id, document_id)
    { 'kind' => kind, 'dataset_id' => dataset_id, 'document_id' => document_id, 'title' => 'Title', 'content' => 'Content', 'score' => 0.9 }
  end

  before do
    public_document.update_columns(metadata: { 'dify_document_id' => 'dify-public' }) # rubocop:disable Rails/SkipsModelValidations
    internal_document.update_columns(metadata: { 'dify_document_id' => 'dify-internal' }) # rubocop:disable Rails/SkipsModelValidations
    create(:captain_assistant_response, assistant: assistant, account: account, documentable: nil, dify_document_id: 'faq-manual')
    create(:captain_assistant_response, assistant: assistant, account: account, documentable: nil, dify_document_id: 'faq-internal',
                                        agents_only: true)
    create(:captain_assistant_response, assistant: assistant, account: account, documentable: internal_document,
                                        dify_document_id: 'faq-from-internal-doc')

    allow(assistant).to receive(:ensure_dify_datasets!)
    allow(AiAgents::KnowledgeClient).to receive(:new).and_return(knowledge_client)
    allow(knowledge_client).to receive(:request).and_return(
      instance_double(HTTParty::Response, code: 200, parsed_response: {
                        'passages' => [
                          passage('document', 'docs-ds', 'dify-public'), passage('document', 'docs-ds', 'dify-internal'),
                          passage('faq', 'faq-ds', 'faq-manual'), passage('faq', 'faq-ds', 'faq-internal'),
                          passage('faq', 'faq-ds', 'faq-from-internal-doc')
                        ]
                      })
    )
  end

  it 'leaves agents-only documents and FAQs, and FAQs made from them, out of customer searches' do
    references = described_class.new(assistant).search('nie').map(&:source_reference)

    expect(references).to contain_exactly("doc:#{public_document.id}", "faq:#{assistant.responses.find_by(dify_document_id: 'faq-manual').id}")
  end

  it 'keeps everything for agents' do
    expect(described_class.new(assistant, for_agents: true).search('nie').size).to eq(5)
  end

  it 'matches the same FAQs with the visible_to_customers scope' do
    expect(assistant.responses.visible_to_customers.pluck(:dify_document_id)).to contain_exactly('faq-manual')
  end
end

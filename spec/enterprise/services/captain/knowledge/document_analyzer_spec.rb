require 'rails_helper'

RSpec.describe Captain::Knowledge::DocumentAnalyzer do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account, name: 'Cleeng Bot', description: 'Subscriber retention assistant') }
  let!(:doc1) do
    create(:captain_document, assistant: assistant, account: account, status: :available,
                              name: 'Hi5 Customer Care', external_link: 'https://help.example.com/hc/en-us/articles/101-hi5',
                              content: 'Hi5 is our AI-powered customer care service for subscriber support.')
  end
  let!(:doc2) do
    create(:captain_document, assistant: assistant, account: account, status: :available,
                              name: 'Merchant Billing', external_link: 'https://help.example.com/hc/en-us/articles/102-merchant',
                              content: 'Merchant handles global subscription billing, tax compliance, and recurring payments.')
  end
  let(:chat) { instance_double(RubyLLM::Chat) }
  let(:llm_response) do
    instance_double(
      RubyLLM::Message,
      content: {
        'page_roles' => %w[service support],
        'overview_score' => 88,
        'support_score' => 75,
        'offerings' => [
          {
            'name' => 'Hi5',
            'kind' => 'service',
            'purpose' => 'AI-powered customer care service for subscriber support.',
            'evidence' => [{ 'passage_id' => 'p0', 'quote' => 'Hi5 is our AI-powered customer care service for subscriber support.' }]
          }
        ]
      },
      input_tokens: 320,
      output_tokens: 95,
      cached_tokens: 40
    )
  end

  before do
    allow(chat).to receive_messages(with_params: chat, with_instructions: chat)
    allow(Captain::Assistant::TieredLlmClient).to receive(:chat).and_return(chat)
    allow(Captain::Assistant::TieredLlmClient).to receive(:generate).and_wrap_original do |_orig, stage, _asst, _chat, _prompt|
      tracker = Thread.current[Captain::Assistant::TieredLlmClient::USAGE_THREAD_KEY]
      if tracker
        tracker[:calls] += 1
        tracker[:input_tokens] += 320
        tracker[:output_tokens] += 95
        tracker[:cached_tokens] += 40
        tracker[:elapsed_ms] += 50
        tracker[:stages][stage.to_s] = { calls: 1, input_tokens: 320, output_tokens: 95, cached_tokens: 40, elapsed_ms: 50 }
      end
      llm_response
    end
  end

  it 'extracts page roles, scores, and verbatim-verified offerings once per content_fingerprint' do
    analysis = described_class.new(document: doc1).perform

    expect(analysis.status).to eq('analyzed')
    expect(analysis.page_roles).to eq(%w[service support])
    expect(analysis.overview_score).to eq(88)
    expect(analysis.offerings.pluck('name')).to eq(['Hi5'])
    expect(analysis.usage).to include('input_tokens' => 320, 'output_tokens' => 95, 'calls' => 1)

    # Re-running with unchanged content reuses cached analysis without calling the LLM again
    described_class.new(document: doc1).perform
    expect(Captain::Assistant::TieredLlmClient).to have_received(:generate).once
  end

  it 'stops cleanly at the configured token budget and resumes from the cursor on the next run' do
    # Budget allows doc1 (~1500 estimated tokens) but not doc2 in the first run
    run1 = described_class.analyze_corpus(assistant: assistant, token_budget: 1600, batch_size: 10)

    expect(run1).to have_attributes(status: 'budget_stopped', cursor: doc1.id, input_tokens: 320, output_tokens: 95, reserved_tokens: 0)
    expect(assistant.knowledge_brief.coverage_summary).to include(
      'eligible' => 2,
      'processed' => 1,
      'pending' => 1,
      'budget_stopped' => true
    )

    # Increasing budget resumes from cursor (doc2) without reprocessing doc1
    allow(llm_response).to receive(:content).and_return(
      'page_roles' => ['product'],
      'overview_score' => 92,
      'support_score' => 60,
      'offerings' => [
        {
          'name' => 'Merchant',
          'kind' => 'product',
          'purpose' => 'Global subscription billing and tax compliance.',
          'evidence' => [{ 'passage_id' => 'p0', 'quote' => 'Merchant handles global subscription billing, tax compliance' }]
        }
      ]
    )

    run2 = described_class.analyze_corpus(assistant: assistant, token_budget: 5000, batch_size: 10, run: run1)

    expect(run2.reload).to have_attributes(status: 'completed', cursor: doc2.id, calls_count: 2)
    expect(assistant.knowledge_brief.coverage_summary).to include(
      'eligible' => 2,
      'processed' => 2,
      'pending' => 0,
      'budget_stopped' => false
    )
  end
end

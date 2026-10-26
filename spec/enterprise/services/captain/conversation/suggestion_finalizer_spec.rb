require 'rails_helper'

RSpec.describe Captain::Conversation::SuggestionFinalizer do
  let(:account) { create(:account) }
  let(:assistant) do
    create(:captain_assistant, account: account,
                               config: { 'suggested_replies' => true, 'max_suggested_replies' => max_suggestions,
                                         'knowledge_brief_enabled' => true })
  end
  let(:max_suggestions) { 3 }
  let(:doc1) do
    create(:captain_document, assistant: assistant, account: account, status: :available,
                              name: 'Core Overview', content: 'Cleeng Core handles entitlements and identity.')
  end
  let(:doc2) do
    create(:captain_document, assistant: assistant, account: account, status: :available,
                              name: 'Merchant & Hi5', content: 'Merchant handles billing. Hi5 handles support.')
  end
  let(:doc3) do
    create(:captain_document, assistant: assistant, account: account, status: :available,
                              name: 'ChurnIQ & Checkout', content: 'ChurnIQ provides analytics. Checkout boosts conversion.')
  end
  let(:tool_state) { {} }
  let(:run_result) { instance_double(Agents::RunResult, context: { state: tool_state }) }

  before do
    offerings = [
      { 'id' => 'core', 'name' => 'Cleeng Core', 'kind' => 'product', 'purpose' => 'Entitlements.', 'status' => 'auto',
        'evidence' => [{ 'document_id' => doc1.id, 'passage_id' => 'p0', 'quote' => 'Cleeng Core handles entitlements' }] },
      { 'id' => 'merchant', 'name' => 'Merchant', 'kind' => 'product', 'purpose' => 'Billing.', 'status' => 'auto',
        'evidence' => [{ 'document_id' => doc2.id, 'passage_id' => 'p0', 'quote' => 'Merchant handles billing.' }] },
      { 'id' => 'hi5', 'name' => 'Hi5', 'kind' => 'service', 'purpose' => 'Support.', 'status' => 'auto',
        'evidence' => [{ 'document_id' => doc2.id, 'passage_id' => 'p0', 'quote' => 'Hi5 handles support.' }] },
      { 'id' => 'churniq', 'name' => 'ChurnIQ', 'kind' => 'product', 'purpose' => 'Analytics.', 'status' => 'auto',
        'evidence' => [{ 'document_id' => doc3.id, 'passage_id' => 'p0', 'quote' => 'ChurnIQ provides analytics.' }] },
      { 'id' => 'checkout', 'name' => 'Checkout', 'kind' => 'product', 'purpose' => 'Conversion.', 'status' => 'auto',
        'evidence' => [{ 'document_id' => doc3.id, 'passage_id' => 'p0', 'quote' => 'Checkout boosts conversion.' }] }
    ]
    candidates = Captain::Knowledge::OfferingReconciler.build_suggestion_candidates(offerings, [])
    assistant.create_knowledge_brief!(
      account: account, status: 'ready',
      published: {
        'schema_version' => 2, 'revision' => 'rev-101', 'document_ids' => [doc1.id, doc2.id, doc3.id],
        'overview' => { 'text' => 'Overview', 'document_ids' => [doc1.id] },
        'topics' => [], 'offerings' => offerings, 'suggestion_candidates' => candidates
      }
    )
  end

  describe 'exact count and fallback filling' do
    [1, 3, 5].each do |target_count|
      context "when max_suggested_replies is #{target_count}" do
        let(:max_suggestions) { target_count }

        it "returns exactly #{target_count} distinct suggestions by filling from the published brief pool" do
          response = {
            'response_parts' => [{ 'text' => 'We help media brands manage subscriptions.', 'citation_indexes' => [] }],
            'suggested_replies' => [{ 'label' => 'Pricing plans', 'message' => 'How does pricing work?' }]
          }

          items = described_class.new(assistant: assistant, response: response, run_result: run_result).perform

          expect(items.size).to eq(target_count)
          expect(items.pluck('title').uniq.size).to eq(target_count)
          expect(tool_state[:suggestion_metrics]).to include(requested: target_count, delivered: target_count, snapshot_revision: 'rev-101')
        end
      end
    end
  end

  it 'preserves natural multi-word labels, deduplicates post-truncation collisions, and filters proactive cancellation/refund prompts' do
    response = {
      'response_parts' => [{ 'text' => 'Your subscription is active.', 'citation_indexes' => [] }],
      'suggested_replies' => [
        { 'label' => 'Configure email notifications', 'message' => 'How do I configure email notifications?' },
        { 'label' => 'Enterprise subscription billing and invoicing guide for teams', 'message' => 'How do invoices work?' },
        { 'label' => 'Enterprise subscription billing and invoicing guide for admins', 'message' => 'How do payment methods work?' },
        { 'label' => 'Cancel subscription', 'message' => 'How do I cancel my subscription and get a refund?' },
        { 'label' => 'Learn more', 'message' => '' }
      ]
    }

    items = described_class.new(assistant: assistant, response: response, run_result: run_result).perform

    expect(items.size).to eq(3)
    expect(items.pluck('title').uniq.size).to eq(3)
    expect(items.pluck('title')).to include('Configure email notifications')
    expect(items.pluck('title')).not_to include('Cancel subscription', 'Learn more')
  end

  it 'allows cancellation/refund suggestions when the customer explicitly asked about refunds' do
    response = {
      'response_parts' => [{ 'text' => 'Refunds are processed within 5 business days.', 'citation_indexes' => [] }],
      'suggested_replies' => [
        { 'label' => 'Refund eligibility', 'message' => 'Who is eligible for a refund?' }
      ]
    }

    items = described_class.new(
      assistant: assistant, response: response, run_result: run_result, customer_message: 'How do refunds work?'
    ).perform

    expect(items.first).to include('title' => 'Refund eligibility')
  end

  it 'marks model choices as choice and fallback fills as follow_up when the reply ends with a question' do
    assistant.update!(config: assistant.config.merge('max_suggested_replies' => 4))
    response = {
      'response_parts' => [{ 'text' => 'Do you prefer monthly or annual billing?', 'citation_indexes' => [] }],
      'suggested_replies' => [
        { 'label' => 'Monthly billing', 'message' => 'I prefer monthly billing.' },
        { 'label' => 'Annual billing', 'message' => 'I prefer annual billing.' }
      ]
    }

    items = described_class.new(
      assistant: assistant, response: response, run_result: run_result, has_closing_question: true
    ).perform

    expect(items.size).to eq(4)
    expect(items.first(2).pluck('kind')).to eq(%w[choice choice])
    expect(items.last(2).pluck('kind')).to eq(%w[follow_up follow_up])
  end

  it 'immediately stops using fallback candidates whose supporting document is disabled or made agents_only' do
    doc2.update!(enabled: false)
    doc3.update!(agents_only: true)
    response = {
      'response_parts' => [{ 'text' => 'Welcome to our platform.', 'citation_indexes' => [] }],
      'suggested_replies' => []
    }

    items = described_class.new(assistant: assistant, response: response, run_result: run_result).perform

    expect(items.pluck('title')).to eq(['Cleeng Core'])
    expect(tool_state[:suggestion_metrics]).to include(delivered: 1, reason: 'insufficient_fallback_pool')
  end

  describe 'open-ended questions and qualification blocking' do
    it 'returns empty suggestions when the reply ends with a question and model suggestions are empty' do
      response = {
        'response_parts' => [{
          'text' => 'What does your company offer, and what would you like the platform to help you manage?',
          'citation_indexes' => []
        }],
        'suggested_replies' => []
      }

      items = described_class.new(
        assistant: assistant, response: response, run_result: run_result, has_closing_question: true
      ).perform

      expect(items).to be_empty
      expect(tool_state[:suggestion_metrics]).to include(
        mode: 'blocking_input',
        reason: 'open_question_without_model_choices',
        delivered: 0
      )
    end

    it 'suppresses fallback suggestions when asking for company name, country, audience size, name, or email even as an imperative' do
      [
        'Please share your company name, country, and approximate audience size.',
        'Please share your name and email so our team can follow up.',
        'What is your company name?'
      ].each do |prompt_text|
        response = {
          'response_parts' => [{ 'text' => prompt_text, 'citation_indexes' => [] }],
          'suggested_replies' => []
        }

        items = described_class.new(
          assistant: assistant, response: response, run_result: run_result, has_closing_question: false
        ).perform

        expect(items).to be_empty
        expect(tool_state[:suggestion_metrics]).to include(
          mode: 'blocking_input',
          delivered: 0
        )
      end
    end
  end
end

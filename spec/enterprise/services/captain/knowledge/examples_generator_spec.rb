require 'rails_helper'

RSpec.describe Captain::Knowledge::ExamplesGenerator do
  let(:assistant) { create(:captain_assistant, name: 'Ava', description: 'Helps customers of a bike shop') }
  let(:brief) { assistant.create_knowledge_brief!(account: assistant.account) }
  let(:chat) { instance_double(RubyLLM::Chat) }
  let(:output) do
    {
      'question' => 'Do you repair e-bikes?',
      'replies' => { 'friendly' => 'Happy to help!', 'professional' => 'Certainly.', 'short' => 'Yes.' },
      'how_to' => { 'question' => 'How do I book a repair?', 'short' => 'Book it online.',
                    'balanced' => "Book it online.\n1. Pick a time.\n2. Confirm.",
                    'detailed' => "Book it online.\n1. Pick a shop.\n2. Pick a time.\n3. Confirm." },
      'quick_replies' => ['Book a repair', 'Opening hours', 'Talk to someone', 'Service prices', 'E-bike batteries'],
      'off_limits_question' => 'Which stock should I buy?',
      'guardrails' => ['No medical advice.', 'No payment details.', 'No competitor comparisons.'],
      'guidelines' => ['Keep replies short.', 'Use plain language.', 'Offer next steps.'],
      'handoff_question' => 'I want a refund for my repair.',
      'starter_questions' => ['Do you sell helmets?', 'How long does a service take?', 'Can I return a bike?']
    }
  end

  before do
    allow(chat).to receive_messages(with_params: chat, with_instructions: chat)
    allow(Captain::Assistant::TieredLlmClient).to receive(:chat).and_return(chat)
    allow(Captain::Assistant::TieredLlmClient).to receive(:generate).and_return(instance_double(RubyLLM::Message, content: output))
  end

  it 'stores the examples with the fingerprint of the business details they were made from' do
    described_class.new(brief).perform

    expect(brief.reload.examples['data']).to eq(output.merge('sources' => {}))
    expect(brief.examples['fingerprint']).to eq(brief.examples_fingerprint)
    expect(brief.examples_due?).to be(false)
  end

  it 'attaches the page each example question comes from' do
    document = create(:captain_document, assistant: assistant, account: assistant.account, status: :available,
                                         name: 'Booking a repair', external_link: 'https://bikes.example/repairs')
    output['how_to']['source_document_id'] = document.id
    output['source_document_id'] = 999_999
    allow(SsrfFilter::DEFAULT_RESOLVER).to receive(:call).with('bikes.example').and_return([IPAddr.new('93.184.216.34')])

    described_class.new(brief).perform

    expect(brief.reload.examples.dig('data', 'sources')).to eq(
      'how_to' => { 'title' => 'Booking a repair', 'url' => 'https://bikes.example/repairs' }
    )
  end

  it 'skips the model when the business details have not changed' do
    brief.update!(examples: { 'fingerprint' => brief.examples_fingerprint })
    described_class.new(brief).perform

    expect(Captain::Assistant::TieredLlmClient).not_to have_received(:generate)
  end

  it 'rejects a how-to example missing an answer length' do
    output['how_to'].delete('detailed')

    expect(described_class.valid_output?(output)).to be(false)
  end

  it 'rejects fewer quick replies than the preview can show' do
    output['quick_replies'] = output['quick_replies'].first(3)

    expect { described_class.new(brief).perform }.to raise_error(TypeError)
  end

  it 'rejects output with missing tones' do
    output['replies'].delete('short')

    expect { described_class.new(brief).perform }.to raise_error(TypeError)
  end
end

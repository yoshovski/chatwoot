require 'rails_helper'

RSpec.describe Captain::Knowledge::GroundedFaqGenerator do
  let(:assistant) { create(:captain_assistant, config: { 'knowledge_processing_version' => 3 }) }
  let(:banner) { 'Download the playbook with retention benchmarks for every subscription business today.' }
  let(:fact) { 'Pausing a subscription keeps the subscriber and stops billing until the chosen date.' }
  let(:document) { create(:captain_document, assistant: assistant, name: 'Pauses', content: "## Pauses\n\n#{fact}\n\n## Playbook\n\n#{banner}") }
  let(:chat) { instance_double(RubyLLM::Chat) }

  before do
    allow(chat).to receive_messages(with_params: chat, with_instructions: chat)
    allow(Captain::Assistant::TieredLlmClient).to receive(:chat).and_return(chat)
    allow(Captain::Assistant::TieredLlmClient).to receive(:generate).and_return(
      instance_double(RubyLLM::Message, content: { 'faqs' => [{ 'question' => 'Can I pause my subscription?', 'paragraph_id' => 0 },
                                                              { 'question' => 'Where is the playbook?', 'paragraph_id' => 1 },
                                                              { 'question' => 'How do I get the benchmarks?', 'paragraph_id' => 1 }] })
    )
  end

  it 'skips answers that repeat another FAQ of the agent or each other' do
    other = create(:captain_document, assistant: assistant, content: 'Other page text')
    create(:captain_assistant_response, assistant: assistant, documentable: other, question: 'Playbook?', answer: banner)

    described_class.new(document).perform(force: true)

    expect(document.responses.pluck(:question)).to eq(['Can I pause my subscription?'])
  end
end

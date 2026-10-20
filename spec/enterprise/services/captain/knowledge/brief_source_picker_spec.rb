require 'rails_helper'

RSpec.describe Captain::Knowledge::BriefSourcePicker do
  let(:assistant) { create(:captain_assistant) }
  let(:brief) { assistant.create_knowledge_brief!(account: assistant.account) }
  let!(:documents) do
    (1..25).map do |index|
      create(:captain_document, assistant: assistant, account: assistant.account, status: :available,
                                external_link: "https://www.example.com/#{'deep/' * (index % 3)}page-#{index}")
    end
  end
  let(:chat) { instance_double(RubyLLM::Chat) }

  before do
    allow(chat).to receive_messages(with_params: chat, with_instructions: chat)
    allow(Captain::Assistant::TieredLlmClient).to receive(:chat).and_return(chat)
  end

  it 'keeps the ids the model picks from the candidates' do
    allow(Captain::Assistant::TieredLlmClient).to receive(:generate)
      .and_return(instance_double(RubyLLM::Message, content: { 'document_ids' => [documents[3].id, 999_999, documents[7].id] }))

    expect(described_class.new(brief).perform).to eq([documents[3].id, documents[7].id])
  end

  it 'falls back to the shortest URLs when the model fails' do
    allow(Captain::Assistant::TieredLlmClient).to receive(:generate).and_raise(Faraday::TimeoutError)
    picked = described_class.new(brief).perform

    expect(picked.size).to eq(described_class::MAX_PICKS)
    expect(Captain::Document.where(id: picked).pluck(:external_link)).to all(satisfy { |link| link.count('/') <= 5 })
  end
end

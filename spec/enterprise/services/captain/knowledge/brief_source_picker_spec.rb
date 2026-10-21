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

  it 'keeps the ids the model picks from the candidates with a short reason for each' do
    picks = [{ 'id' => documents[3].id, 'reason' => 'Company overview' }, { 'id' => 999_999, 'reason' => 'Invented' },
             { 'id' => documents[7].id, 'reason' => 'Pricing' }]
    allow(Captain::Assistant::TieredLlmClient).to receive(:generate)
      .and_return(instance_double(RubyLLM::Message, content: { 'documents' => picks }))
    picker = described_class.new(brief)

    expect(picker.perform).to eq([documents[3].id, documents[7].id])
    expect(picker.reasons).to eq(documents[3].id => 'Company overview', documents[7].id => 'Pricing')
  end

  it 'falls back to the shortest URLs when the model fails' do
    allow(Captain::Assistant::TieredLlmClient).to receive(:generate).and_raise(Faraday::TimeoutError)
    picked = described_class.new(brief).perform

    expect(picked.size).to eq(described_class::MAX_PICKS)
    expect(Captain::Document.where(id: picked).pluck(:external_link)).to all(satisfy { |link| link.count('/') <= 5 })
  end

  it 'prioritizes uploaded docs, homepages, and core business pages over blogs' do
    expect(described_class.relevance_rank('Company Guide', nil).first).to eq(0)
    expect(described_class.relevance_rank('Home', 'https://example.com/').first).to eq(1)
    expect(described_class.relevance_rank('Pricing', 'https://example.com/pricing').first).to eq(2)
    expect(described_class.relevance_rank('Features', 'https://example.com/products/retention').first).to eq(2)
    expect(described_class.relevance_rank('Blog', 'https://example.com/blog/article-1').first).to eq(4)
    expect(described_class.relevance_rank('Podcast', 'https://example.com/podcasts/ep-1').first).to eq(4)
    expect(described_class.relevance_rank('Other Page', 'https://example.com/other').first).to eq(3)
  end
end

require 'rails_helper'

RSpec.describe Captain::Websites::SectionClassifier do
  let(:assistant) { create(:captain_assistant, name: 'Support agent', description: 'Answers subscriber questions') }
  let(:source) do
    Captain::WebsiteSource.create!(
      assistant: assistant, url: 'https://www.example.com', status: 'ready',
      pages: [
        { 'url' => 'https://www.example.com/help/billing', 'title' => 'Billing help', 'section' => 'example.com/help', 'bucket' => 'recommended' },
        { 'url' => 'https://blog.example.com/news', 'title' => 'Launch news', 'section' => 'blog.example.com/news', 'bucket' => 'maybe' },
        { 'url' => 'https://api.example.com/v1', 'section' => 'api.example.com/v1', 'bucket' => 'excluded' }
      ]
    )
  end
  let(:chat) { instance_double(RubyLLM::Chat) }
  let(:output) do
    { 'sections' => [
      { 'id' => 0, 'label' => 'support', 'recommended' => true, 'reason' => 'Billing help articles' },
      { 'id' => 1, 'label' => 'invented', 'recommended' => false, 'reason' => 'Unknown label' },
      { 'id' => 9, 'label' => 'news', 'recommended' => false, 'reason' => 'Out of range' }
    ] }
  end

  before do
    allow(chat).to receive_messages(with_params: chat, with_instructions: chat)
    allow(Captain::Assistant::TieredLlmClient).to receive(:chat).and_return(chat)
    allow(Captain::Assistant::TieredLlmClient).to receive(:generate)
      .and_return(instance_double(RubyLLM::Message, content: output))
  end

  it 'labels candidate sections and drops invalid labels' do
    expect(described_class.new(source).perform).to eq(
      'example.com/help' => { 'label' => 'support', 'recommended' => true, 'reason' => 'Billing help articles' }
    )
  end

  it 'sends only non-excluded sections with the agent context' do
    described_class.new(source).perform

    expect(Captain::Assistant::TieredLlmClient).to have_received(:generate) do |stage, _assistant, _chat, input|
      payload = JSON.parse(input)
      expect(stage).to eq('website_classification')
      expect(payload['agent']).to eq('name' => 'Support agent', 'description' => 'Answers subscriber questions')
      expect(payload['sections'].pluck('section')).to eq(%w[example.com/help blog.example.com/news])
    end
  end
end

require 'rails_helper'

RSpec.describe Captain::AssistantSettingsImporter do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account, config: { 'temperature' => 0.7 }) }
  let(:settings) do
    {
      'description' => 'Official assistant of Acme Store.',
      'response_guidelines' => ['Lead with the answer.'],
      'guardrails' => ['Answer only about Acme Store.'],
      'config' => {
        'product_name' => 'Acme equipment',
        'hide_stock' => true,
        'link_allowlist' => ['https://acme.example/'],
        'image_allowlist' => ['https://acme.example/cdn/']
      },
      'scenarios' => [{ 'title' => 'Request a quote', 'description' => 'Handles quotes.', 'instruction' => 'Ask for items, then hand off.' }],
      'responses' => [{ 'question' => 'Track My Order', 'answer' => 'Please share your order number and checkout email.' }]
    }
  end

  it 'applies prompts, rules and config, adding allowlists to the store defaults' do
    described_class.apply!(assistant: assistant, settings: settings)

    assistant.reload
    expect(assistant.description).to eq('Official assistant of Acme Store.')
    expect(assistant.response_guidelines).to eq(['Lead with the answer.'])
    expect(assistant.guardrails).to eq(['Answer only about Acme Store.'])
    expect(assistant.config).to include('temperature' => 0.7, 'product_name' => 'Acme equipment', 'hide_stock' => true)
    expect(assistant.link_allowlist).to eq(['https://acme.example/'])
    expect(assistant.image_allowlist).to eq(['https://cdn.shopify.com/', 'https://acme.example/cdn/'])
  end

  it 'creates the scenarios and approved replies, and updates them in place on re-run' do
    described_class.apply!(assistant: assistant, settings: settings)
    settings['responses'].first['answer'] = 'Share your order number.'
    described_class.apply!(assistant: assistant, settings: settings)

    expect(assistant.scenarios.pluck(:title, :enabled)).to eq([['Request a quote', true]])
    expect(assistant.responses.pluck(:question, :answer, :status)).to eq([['Track My Order', 'Share your order number.', 'approved']])
  end
end

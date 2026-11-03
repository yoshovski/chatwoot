require 'rails_helper'

RSpec.describe Captain::PromptRenderer do
  let(:visitor_context) do
    { location: 'Valencia, Spain', local_time: 'Wednesday 18:30 (CET)',
      returning: { visit: '3rd', earlier_conversations: 1, last_conversation_status: 'resolved', first_seen_on: '2026-10-01' },
      arrival: { 'referrer_host' => 'www.google.com', 'utm_campaign' => 'spring-sale' } }
  end
  let(:context) { { product_name: 'Acme', first_ai_reply: true, conversation: { id: 1 }, visitor_context: visitor_context } }
  let(:prompts) { %w[assistant direct_response].map { |name| described_class.render(name, context.with_indifferent_access) } }

  it 'renders the visitor context lines in both prompts' do
    expect(prompts).to all(include(
                             'Detected location (approximate): Valencia, Spain',
                             "Visitor's local time: Wednesday 18:30 (CET)",
                             'Returning visitor: 3rd visit, 1 earlier conversation (last one resolved), first seen 2026-10-01',
                             'Arrived from: www.google.com, campaign spring-sale',
                             'Never list the collected context back to the customer',
                             'may say "welcome back"'
                           ))
  end

  it 'leaves out lines without data and the welcome back after the first reply' do
    context[:first_ai_reply] = false
    context[:visitor_context] = { location: 'Valencia, Spain' }

    expect(prompts).to all(include('Detected location (approximate): Valencia, Spain'))
    prompts.each do |prompt|
      expect(prompt).not_to include("Visitor's local time", 'Returning visitor', 'Arrived from', 'welcome back')
    end
  end

  it 'offers the welcome back only to returning visitors' do
    context[:visitor_context] = { location: 'Valencia, Spain' }

    expect(prompts).to all(include('This is your first reply in this conversation'))
    prompts.each { |prompt| expect(prompt).not_to include('welcome back') }
  end
end

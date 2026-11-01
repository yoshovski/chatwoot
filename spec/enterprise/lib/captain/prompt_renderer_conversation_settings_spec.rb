require 'rails_helper'

RSpec.describe Captain::PromptRenderer do
  let(:account) { create(:account) }
  let(:config) { { 'product_name' => 'Acme Streaming Tools' } }
  let(:assistant) { create(:captain_assistant, account: account, name: 'Ava', config: config) }
  let(:context) { assistant.prompt_context }
  let(:assistant_prompt) { described_class.render('assistant', context.with_indifferent_access) }
  let(:direct_prompt) { described_class.render('direct_response', context.with_indifferent_access) }

  describe 'role' do
    context 'with the all-round role' do
      let(:config) { { 'product_name' => 'Acme Streaming Tools', 'agent_role' => 'adaptive' } }

      it 'decides per conversation between support, sales and shopping in both prompts' do
        expect([assistant_prompt, direct_prompt]).to all(include(
                                                           'Decide in each conversation what the visitor needs',
                                                           'solve their problem fully, without a sales pitch',
                                                           'find the best fit'
                                                         ))
        expect(direct_prompt).not_to include('customer support assistant')
      end
    end
  end

  describe 'audience' do
    context 'with detect' do
      let(:config) { { 'product_name' => 'Acme Streaming Tools', 'visitor_audience' => 'detect' } }

      it 'decides from what the visitor says' do
        expect([assistant_prompt, direct_prompt]).to all(include('Visitors may be prospects or existing customers', 'at most one short setup hint'))
      end
    end
  end

  describe 'business interest on the direct route' do
    let(:lead_config) do
      { 'leads_enabled' => true, 'lead_types' => [{ 'name' => 'Demo', 'rule' => 'Wants a demo' }] }
    end

    it 'is not shown without lead capture' do
      assistant.update!(config: config.merge('agent_role' => 'sales'))

      expect(direct_prompt).not_to include('Business interest:')
    end

    it 'offers one question or the follow-up for a sales agent with lead capture' do
      assistant.update!(config: config.merge(lead_config, 'agent_role' => 'sales', 'visitor_audience' => 'customers'))

      expect(direct_prompt).to include('Business interest: answer the question first.', 'in its own final response part')
      expect(direct_prompt).not_to include('Business lead capture')
    end

    it 'offers the follow-up for an all-round agent even for customers' do
      assistant.update!(config: config.merge(lead_config, 'agent_role' => 'adaptive', 'visitor_audience' => 'customers'))

      expect(direct_prompt).to include('Business interest: answer the question first.')
    end

    it 'only offers the follow-up when no questions remain' do
      assistant.update!(config: config.merge(lead_config, 'visitor_audience' => 'detect'))
      prompt = described_class.render('direct_response', context.merge(lead_questions_remaining: 0).with_indifferent_access)

      expect(prompt).to include('end with an offer of the email follow-up or a demo')
      expect(prompt).not_to include('one short question about their goal')
    end

    it 'keeps the full lead rules in the main prompt' do
      assistant.update!(config: config.merge(lead_config, 'agent_role' => 'sales'))

      expect(assistant_prompt).to include('## Business lead capture')
    end
  end

  describe 'greeting' do
    let(:first_reply_context) { context.merge(first_ai_reply: true).with_indifferent_access }

    it 'asks for a short welcome in the first reply of both prompts' do
      prompts = %w[assistant direct_response].map { |template| described_class.render(template, first_reply_context) }

      expect(prompts).to all(include('Write a short, warm welcome'))
    end
  end

  describe 'limits' do
    let(:config) do
      { 'product_name' => 'Acme Streaming Tools', 'limits' => [
        { 'cannot' => 'issue refunds', 'offer' => 'handoff' },
        { 'cannot' => 'change a subscription plan', 'offer' => 'email_followup' },
        { 'cannot' => 'give legal advice', 'offer' => 'link', 'value' => 'https://example.com/legal' },
        { 'cannot' => 'book a call', 'offer' => 'text', 'value' => 'Email hello@example.com to book a call.' }
      ] }
    end

    it 'lists what the agent cannot do and what it offers instead in both prompts' do
      expect([assistant_prompt, direct_prompt]).to all(include(
                                                         '# What You Can\'t Do', 'You can\'t issue refunds.',
                                                         'You can\'t give legal advice. Share this link: https://example.com/legal',
                                                         'Say this, in the customer\'s language: "Email hello@example.com to book a call."'
                                                       ))
    end

    it 'hands off through the protocol in the main prompt and the schema flag on the direct route' do
      expect(assistant_prompt).to include('Follow the Human Handoff Protocol to bring in a colleague.',
                                          '`captain--tools--request_lead_followup`')
      expect(direct_prompt).to include('Say a colleague will continue in this chat and set handoff_requested to true.',
                                       'Offer an email follow-up from the team.')
    end

    it 'adds nothing without limits' do
      assistant.update!(config: config.merge('limits' => []))

      expect(assistant_prompt).not_to include("What You Can't Do")
    end
  end

  it 'describes software visitors without assuming they are customers' do
    assistant.update!(config: config.merge('business_type' => 'software'))

    expect(assistant_prompt).to include('Visitors may be evaluating the product, using it, or building on it')
  end
end

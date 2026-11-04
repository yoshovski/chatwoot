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

  describe 'fixed role' do
    let(:config) do
      { 'product_name' => 'Fernbrook Gardens', 'agent_role' => 'custom', 'agent_role_prompt' => 'You only talk about roses.',
        'visitor_audience' => 'customers' }
    end

    it 'tells customers, prospects and shoppers apart in both prompts, whatever an older setting stored' do
      expect([assistant_prompt, direct_prompt]).to all(include(
                                                         'You are Ava, the assistant for Fernbrook Gardens.',
                                                         'solve their problem fully, without a sales pitch',
                                                         "Don't give in-product click paths, admin steps or settings locations",
                                                         'find the best fit',
                                                         'at most one short setup hint'
                                                       ))
      [assistant_prompt, direct_prompt].each do |prompt|
        expect(prompt).not_to include('You only talk about roses.', '# Visitors', 'customer support assistant')
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

    it 'welcomes only in the first reply, whatever an older setting stored' do
      assistant.update!(config: config.merge('greeting_mode' => 'fixed', 'welcome_message' => 'Hi there!'))
      first_reply = described_class.render('direct_response', assistant.prompt_context.merge(first_ai_reply: true).with_indifferent_access)

      expect(first_reply).to include('Write a short, warm welcome')
      expect(first_reply).not_to include('A welcome message is sent just before your reply')
      expect(assistant_prompt).not_to include('warm welcome')
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

    # The reply eval's R08: the action model explained the refund policy and promised a colleague without handing off.
    it 'hands off at once for a handoff limit, without policy details, and never promises a colleague otherwise' do
      expect(assistant_prompt).to include(
        "say plainly in one sentence that you can't, without the policy or other details behind it, then take the next step listed:",
        'This limit requires the transfer: call `captain--tools--handoff` right away, without asking first, ' \
        'and say a colleague will continue in this chat.',
        'Never say a colleague will reply or continue in this chat unless you call `captain--tools--handoff` in this reply.'
      )
      expect(direct_prompt).to include('Never say a colleague will reply or continue in this chat without setting handoff_requested to true.')
    end

    it 'adds no colleague rule without a handoff limit' do
      assistant.update!(config: config.merge('limits' => config['limits'].reject { |limit| limit['offer'] == 'handoff' }))

      expect([assistant_prompt, direct_prompt]).to all(satisfy { |prompt| prompt.exclude?('Never say a colleague will reply') })
    end

    it 'adds nothing without limits' do
      assistant.update!(config: config.merge('limits' => []))

      expect(assistant_prompt).not_to include("What You Can't Do")
    end
  end

  describe 'scenario prompt' do
    let(:config) { { 'product_name' => 'Fernbrook Gardens', 'limits' => [{ 'cannot' => 'issue refunds', 'offer' => 'handoff' }] } }
    let(:scenario) { create(:captain_scenario, assistant: assistant, title: 'Planting plan', instruction: 'Ask for the bed size.') }
    let(:scenario_prompt) { described_class.render('scenario', scenario.prompt_context.with_indifferent_access) }

    it 'knows what the agent cannot do' do
      expect(scenario_prompt).to include("You can't issue refunds. Bring in a colleague with `captain--tools--handoff`")
    end

    it 'hands off at once for a handoff limit' do
      expect(scenario_prompt).to include(
        'Bring in a colleague with `captain--tools--handoff` right away, without asking first, and say they will continue in this chat.',
        'Never say a colleague will reply or continue in this chat unless you call `captain--tools--handoff` in this reply.'
      )
    end
  end

  describe 'behaviour block parity' do
    let(:lead_config) { { 'leads_enabled' => true, 'lead_types' => [{ 'name' => 'Demo', 'rule' => 'Wants a demo' }] } }
    let(:limit_config) { { 'limits' => [{ 'cannot' => 'issue refunds', 'offer' => 'handoff' }] } }
    let(:welcome_line) { 'Write a short, warm welcome' }
    let(:role_line) { 'You are Ava, the assistant for Acme Streaming Tools. Decide in each conversation what the visitor needs' }
    let(:limit_lines) do
      { 'assistant' => "You can't issue refunds. Follow the Human Handoff Protocol to bring in a colleague.",
        'direct_response' => "You can't issue refunds. Say a colleague will continue in this chat and set handoff_requested to true.",
        'scenario' => "You can't issue refunds. Bring in a colleague with `captain--tools--handoff`" }
    end

    [true, false].product([true, false], [true, false], [true, false], [true, false]).each do |first_reply, opener, leads, limits, email|
      it "renders the same behaviour lines (first reply #{first_reply}, opener #{opener}, leads #{leads}, limits #{limits}, " \
         "email #{email})" do
        assistant.update!(config: config.merge(leads ? lead_config : {}, limits ? limit_config : {}))
        scenario = create(:captain_scenario, assistant: assistant, title: 'Planting plan', instruction: 'Ask for the bed size.')
        runtime = { first_ai_reply: first_reply && !opener, campaign: opener ? { id: 7, title: 'Spring offer' } : {},
                    message_length_limit: email ? nil : 1000, visitor_context: { returning: { earlier_conversations: 1 } } }
        prompts = { 'assistant' => assistant.prompt_context, 'direct_response' => assistant.prompt_context,
                    'scenario' => scenario.prompt_context }.to_h do |template, base|
          [template, described_class.render(template, base.merge(runtime).with_indifferent_access)]
        end

        prompts.each do |template, prompt|
          expect(prompt.include?(welcome_line)).to eq(first_reply && !opener)
          expect(prompt.include?('welcome back')).to eq(first_reply && !opener)
          expect(prompt.include?(role_line)).to eq(template != 'scenario')
          expect(prompt.include?("# What You Can't Do")).to eq(limits)
          expect(prompt.include?(limit_lines.fetch(template))).to eq(limits)
        end
        expect(prompts.values_at('assistant', 'scenario').map { |prompt| prompt.include?('## Business lead capture') }).to all(eq(leads))
        expect(prompts['direct_response'].include?('Business interest:')).to eq(leads)
      end
    end
  end

  it 'describes software visitors without assuming they are customers' do
    assistant.update!(config: config.merge('business_type' => 'software'))

    expect(assistant_prompt).to include('Visitors may be evaluating the product, using it, or building on it')
  end
end

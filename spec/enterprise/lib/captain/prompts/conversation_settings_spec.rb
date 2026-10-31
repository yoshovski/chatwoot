require 'rails_helper'

RSpec.describe Captain::PromptRenderer do
  let(:account) { create(:account) }
  let(:config) { { 'product_name' => 'Acme Streaming Tools' } }
  let(:assistant) { create(:captain_assistant, account: account, name: 'Ava', config: config) }
  let(:context) { assistant.prompt_context }
  let(:assistant_prompt) { described_class.render('assistant', context.with_indifferent_access) }
  let(:direct_prompt) { described_class.render('direct_response', context.with_indifferent_access) }

  describe 'role' do
    it 'keeps the support identity of each prompt' do
      expect(assistant_prompt).to include('You are Ava, a helpful, friendly, and knowledgeable assistant for Acme Streaming Tools.')
      expect(assistant_prompt).to include('Help with anything Acme Streaming Tools offers')
      expect(direct_prompt).to include('You are Ava, the customer support assistant for Acme Streaming Tools.')
    end

    context 'with the sales role' do
      let(:config) { { 'product_name' => 'Acme Streaming Tools', 'agent_role' => 'sales' } }

      it 'helps visitors find out whether the product fits in both prompts' do
        identity = 'You are Ava, who helps visitors find out whether Acme Streaming Tools fits their needs.'
        expect([assistant_prompt, direct_prompt]).to all(include(identity))
        expect(direct_prompt).not_to include('customer support assistant')
        expect(assistant_prompt).to include('Help with anything Acme Streaming Tools offers')
      end
    end

    context 'with the shopping role' do
      let(:config) { { 'product_name' => 'Acme Garden', 'agent_role' => 'shopping' } }

      it 'helps shoppers find the right product' do
        expect([assistant_prompt, direct_prompt]).to all(include('You are Ava, who helps shoppers find the right product at Acme Garden.'))
      end
    end

    context 'with a custom role' do
      let(:config) do
        { 'product_name' => 'Acme Garden', 'agent_role' => 'custom', 'agent_role_prompt' => 'You help gardeners plan their beds.' }
      end

      it 'uses the custom text after the name and product' do
        expect([assistant_prompt, direct_prompt]).to all(include('You are Ava, the assistant for Acme Garden. You help gardeners plan their beds.'))
      end
    end
  end

  describe 'audience' do
    it 'adds nothing for customers' do
      assistant.update!(config: config.merge('visitor_audience' => 'customers'))

      expect(assistant_prompt).not_to include('# Visitors')
      expect(direct_prompt).not_to include('# Visitors')
    end

    context 'with prospects' do
      let(:config) { { 'product_name' => 'Acme Streaming Tools', 'visitor_audience' => 'prospects' } }

      it 'explains what is possible instead of click paths' do
        expect([assistant_prompt, direct_prompt]).to all(include('Visitors are usually not customers yet', "Don't give in-product click paths"))
      end
    end

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

    it 'is not shown to a support agent for customers' do
      assistant.update!(config: config.merge(lead_config, 'visitor_audience' => 'customers'))

      expect(direct_prompt).not_to include('Business interest:')
    end

    it 'offers one question or the follow-up for a sales agent with lead capture' do
      assistant.update!(config: config.merge(lead_config, 'agent_role' => 'sales', 'visitor_audience' => 'customers'))

      expect(direct_prompt).to include('Business interest: answer the question first.', 'in its own final response part')
      expect(direct_prompt).not_to include('Business lead capture')
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

  it 'describes software visitors without assuming they are customers' do
    assistant.update!(config: config.merge('business_type' => 'software'))

    expect(assistant_prompt).to include('Visitors may be evaluating the product, using it, or building on it')
  end
end

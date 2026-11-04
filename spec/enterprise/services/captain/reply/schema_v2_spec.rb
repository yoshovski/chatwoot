# frozen_string_literal: true

require 'rails_helper'

# Schema v2 (CWAI-143): the closing question travels in `follow_up` instead of being found in the prose.
RSpec.describe 'Captain reply schema v2' do # rubocop:disable RSpec/DescribeClass
  let(:account) { create(:account) }
  let(:assistant) do
    create(:captain_assistant, account: account,
                               config: { 'product_name' => 'Lumen Notes', 'suggested_replies' => true, 'max_suggested_replies' => 3,
                                         'leads_enabled' => true, 'lead_types' => [{ 'name' => 'Team plan', 'rule' => 'Wants a team plan' }] })
  end
  let(:run_result) { instance_double(Agents::RunResult, context: { state: {} }) }
  let(:widget_inbox) { create(:inbox, account: account, channel: create(:channel_widget, account: account)) }
  let(:email_inbox) { create(:inbox, account: account, channel: create(:channel_email, account: account)) }

  def payloads(response, inbox: widget_inbox)
    conversation = create(:conversation, account: account, inbox: inbox)
    Captain::Conversation::ReplyComposer.new(assistant: assistant, conversation: conversation, response: response, run_result: run_result,
                                             customer_message: nil).messages
  end

  def prompts(context)
    %w[assistant direct_response].map { |template| Captain::PromptRenderer.render(template, context.with_indifferent_access) }
  end

  describe 'the switch' do
    it 'is off by default' do
      expect(Captain::ResponseSchema.v2?(account.id)).to be(false)
    end

    it 'is on for every account when CAPTAIN_REPLY_SCHEMA_V2 is on' do
      with_modified_env(CAPTAIN_REPLY_SCHEMA_V2: 'on') { expect(Captain::ResponseSchema.v2?(account.id)).to be(true) }
    end

    it 'is on only for the listed accounts when an account list is set' do
      with_modified_env(CAPTAIN_REPLY_SCHEMA_V2: 'on', CAPTAIN_REPLY_SCHEMA_V2_ACCOUNT_IDS: " #{account.id}, 999999") do
        expect(Captain::ResponseSchema.v2?(account.id)).to be(true)
        expect(Captain::ResponseSchema.v2?(account.id + 1)).to be(false)
      end
      with_modified_env(CAPTAIN_REPLY_SCHEMA_V2_ACCOUNT_IDS: account.id.to_s) { expect(Captain::ResponseSchema.v2?(account.id)).to be(true) }
    end
  end

  describe 'with the switch off' do
    it 'keeps the v1 schema' do
      properties = Captain::ResponseSchema.for(lead_capture: true, suggested_replies: true).new.to_json_schema.dig(:schema, :properties)

      expect(properties).to include(:lead_qualification_question)
      expect(properties).not_to include(:follow_up)
    end

    it 'renders the same prompts as without the setting' do
      context = assistant.prompt_context.merge(lead_questions_remaining: 1)

      expect(context[:reply_schema_v2]).to be(false)
      expect(prompts(context)).to eq(prompts(context.except(:reply_schema_v2)))
      expect(prompts(context).join).not_to include('`follow_up`')
      expect(prompts(context).last).to include('Set lead_qualification_question to true only for that qualification question.')
    end
  end

  describe 'with the switch on' do
    around { |example| with_modified_env(CAPTAIN_REPLY_SCHEMA_V2: 'on') { example.run } }

    it 'asks for an optional follow_up instead of lead_qualification_question' do
      properties = Captain::ResponseSchema.for(lead_capture: true, follow_up: true).new.to_json_schema.dig(:schema, :properties)

      expect(properties).not_to include(:lead_qualification_question)
      expect(properties.dig(:follow_up, :anyOf)).to contain_exactly(
        include(type: 'object', properties: include(kind: include(enum: %w[clarification next_step qualification]))), { type: 'null' }
      )
    end

    it 'tells every reply prompt to put the closing question in follow_up' do
      scenario = create(:captain_scenario, assistant: assistant, title: 'Team setup', instruction: 'Ask for the team size.')
      context = assistant.prompt_context.merge(lead_questions_remaining: 1)
      all = [*prompts(context), Captain::PromptRenderer.render('scenario', scenario.prompt_context.with_indifferent_access)]

      expect(all).to all(include('Put a closing question in `follow_up` with its kind, never in `response_parts`.'))
      expect(all).to all(satisfy { |prompt| prompt.exclude?('lead_qualification_question') })
      expect(all.last).to include('Put a follow-up question in `follow_up` so it can appear separately')
      expect(all[1]).to include('Put that question in `follow_up` with kind qualification.')
    end
  end

  describe 'payloads' do
    let(:answer) { 'You can pause a plan for up to three months.' }
    let(:suggestions) { ['Monthly'] }

    it 'are the same for a v1 and a v2 closing question on the widget and by email' do
      v1 = { 'response_parts' => [{ 'text' => answer, 'citation_indexes' => [] }, { 'text' => 'Which plan are you on?', 'citation_indexes' => [] }],
             'suggested_replies' => suggestions }
      v2 = { 'response_parts' => [{ 'text' => answer, 'citation_indexes' => [] }], 'suggested_replies' => suggestions,
             'follow_up' => { 'text' => 'Which plan are you on?', 'kind' => 'clarification' } }

      [widget_inbox, email_inbox].each { |inbox| expect(payloads(v2, inbox: inbox)).to eq(payloads(v1, inbox: inbox)) }
      expect(payloads(v2).pluck(:content)).to eq([answer, 'Which plan are you on?'])
    end

    it 'are the same for a v1 and a v2 qualification question, including the lead question budget attribute' do
      parts = [{ 'text' => 'Team spaces suit groups.', 'citation_indexes' => [] },
               { 'text' => 'Exports work on every plan.', 'citation_indexes' => [] }]
      v1 = { 'lead_qualification_question' => true, 'suggested_replies' => ['Under 10'],
             'response_parts' => [*parts, { 'text' => 'How large is your team?', 'citation_indexes' => [] }] }
      v2 = { 'response_parts' => parts, 'suggested_replies' => ['Under 10'],
             'follow_up' => { 'text' => 'How large is your team?', 'kind' => 'qualification' } }

      expect(payloads(v2)).to eq(payloads(v1))
      expect(payloads(v2).first[:additional_attributes]).to include(Captain::Leads::QuestionBudget::ATTRIBUTE_KEY => true)
    end

    it 'set no lead question attribute for other kinds' do
      v2 = { 'response_parts' => [{ 'text' => answer, 'citation_indexes' => [] }],
             'follow_up' => { 'text' => 'Which plan are you on?', 'kind' => 'next_step' } }

      expect(payloads(v2).first[:additional_attributes]).not_to include(Captain::Leads::QuestionBudget::ATTRIBUTE_KEY)
    end

    {
      'a Chinese question mark' => ['您可以暂停套餐最多三个月。', '您使用的是哪个套餐？'],
      'an Arabic question mark' => ['يمكنك إيقاف الخطة مؤقتًا لمدة تصل إلى ثلاثة أشهر.', 'ما هي الخطة التي تستخدمها؟'],
      'a question ending in a link' => [
        'You can pause a plan for up to three months.', 'Have you seen [the pause guide](https://help.lumen-notes.test/pause)'
      ]
    }.each do |label, (answer_text, question)|
      it "splits #{label} into its own bubble" do
        v2 = { 'response_parts' => [{ 'text' => answer_text, 'citation_indexes' => [] }],
               'follow_up' => { 'text' => question, 'kind' => 'clarification' } }

        expect(payloads(v2).pluck(:content)).to eq([answer_text, question])
      end
    end

    it 'keep a short greeting and its question in one bubble' do
      v2 = { 'response_parts' => [{ 'text' => 'Hi there!', 'citation_indexes' => [] }],
             'follow_up' => { 'text' => 'How can I help?', 'kind' => 'clarification' } }

      expect(payloads(v2).pluck(:content)).to eq(["Hi there!\n\nHow can I help?"])
    end

    it 'read a normalized response once more without adding the question twice' do
      v2 = { 'response_parts' => [{ 'text' => answer, 'citation_indexes' => [] }],
             'follow_up' => { 'text' => 'Which plan are you on?', 'kind' => 'clarification' } }
      normalized = v2.merge('response_parts' => Captain::Assistant::ResponseParts.from_response(v2).to_a)

      expect(normalized['response_parts'].pluck('text')).to eq([answer, 'Which plan are you on?'])
      expect(payloads(normalized)).to eq(payloads(v2))
    end
  end

  describe 'lead question budget' do
    it 'drops a v2 qualification question when no questions remain' do
      assistant.update!(config: assistant.config.merge('lead_max_questions' => 0))
      output = { 'response_parts' => [{ 'text' => 'Team spaces suit groups.', 'citation_indexes' => [] }], 'suggested_replies' => ['Under 10'],
                 'follow_up' => { 'text' => 'How large is your team?', 'kind' => 'qualification' } }
      result = instance_double(Agents::RunResult, context: { state: {} }, output: output)

      Captain::Leads::QuestionBudget.new(assistant, nil).enforce!(result)

      expect(output).to include('response_parts' => [{ 'text' => 'Team spaces suit groups.', 'citation_indexes' => [] }],
                                'suggested_replies' => [])
      expect(output).not_to include('follow_up')
    end
  end
end

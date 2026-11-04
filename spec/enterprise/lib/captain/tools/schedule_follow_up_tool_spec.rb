require 'rails_helper'

RSpec.describe Captain::Tools::ScheduleFollowUpTool do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:tool_context) { Struct.new(:state).new({ conversation: { id: conversation.id } }) }
  let(:params) { { after: '60', kind: 'message', instructions: 'Ask if the plan comparison helped' } }

  it 'schedules one follow-up message per reference' do
    tool = described_class.new(assistant, fixed_params: params)

    freeze_time do
      expect(tool.perform(tool_context)).to include('after 1 hour of quiet')
      expect(tool.perform(tool_context)).to include('after 1 hour of quiet')

      expect(Captain::ScheduledAction.sole).to have_attributes(
        kind: 'follow_up_message', due_at: 1.hour.from_now, dedupe_key: tool.name.delete_prefix('captain--tools--'),
        payload: include('instructions' => 'Ask if the plan comparison helped')
      )
    end
  end

  it 'says no when three follow-ups already wait' do
    3.times { |index| create(:captain_scheduled_action, conversation: conversation, dedupe_key: index.to_s) }

    expect(described_class.new(assistant, fixed_params: params).perform(tool_context)).to include('No follow-up was scheduled')
  end

  it 'validates delay, kind and content' do
    expect(described_class.fixed_param_errors(assistant, 'after' => '5', 'kind' => 'sms')).to contain_exactly(
      'after must be 15-10080 minutes', 'kind must be message or email', 'a follow-up needs a template or instructions'
    )
    expect(described_class.fixed_param_errors(assistant, 'after' => '30', 'kind' => 'email', 'instructions' => 'x')).to eq(
      ['an email follow-up needs a template']
    )
  end
end

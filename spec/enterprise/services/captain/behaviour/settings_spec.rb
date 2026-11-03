require 'rails_helper'

RSpec.describe Captain::Behaviour::Settings do
  let(:limits) { [{ 'cannot' => 'issue refunds', 'offer' => 'handoff' }] }
  let(:lead_types) { [{ 'name' => 'Demo', 'rule' => 'Wants a product demo' }] }
  let(:assistant) do
    create(:captain_assistant, business_type: 'software', config: { 'limits' => limits, 'leads_enabled' => true, 'lead_types' => lead_types })
  end

  it 'reads the reply-shaping content of one agent' do
    behaviour = Captain::Behaviour.for(assistant)

    expect(behaviour).to have_attributes(limits: limits, leads_enabled?: true, business_type: 'software')
    expect(behaviour.prompt_context).to include(business_type: 'software', limits: limits, lead_capture: include(types: lead_types),
                                                answer_length: 'balanced')
  end

  it 'gives the agent and scenario prompts the same behaviour context' do
    scenario = create(:captain_scenario, assistant: assistant, account: assistant.account)

    expect(assistant.prompt_context).to include(Captain::Behaviour.for(assistant).prompt_context)
    expect(scenario.prompt_context).to include(Captain::Behaviour.for(assistant).prompt_context.except(:business_type))
  end
end

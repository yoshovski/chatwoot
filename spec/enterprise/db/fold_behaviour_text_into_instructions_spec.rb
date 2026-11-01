require 'rails_helper'
require Rails.root.join('db/migrate/20261101120000_fold_behaviour_text_into_instructions.rb')

RSpec.describe FoldBehaviourTextIntoInstructions do
  let(:migration) { described_class.new }
  let(:assistant) { create(:captain_assistant, response_guidelines: ['Mention free returns.']) }
  let(:behaviour) do
    { 'agent_role' => 'custom', 'agent_role_prompt' => 'You help gardeners plan their beds.',
      'greeting_mode' => 'fixed', 'welcome_message' => 'Hi {{ contact.first_name }}, welcome to Fernbrook Gardens!' }
  end

  before { assistant.update_columns(config: assistant.config.merge(behaviour)) } # rubocop:disable Rails/SkipsModelValidations

  it 'appends the custom role and fixed welcome to the instructions and keeps the old values' do
    migration.up
    assistant.reload

    expect(assistant.response_guidelines).to eq(
      ['Mention free returns.', 'Role: You help gardeners plan their beds.',
       "Use this welcome on the first reply: Hi [the customer's first name], welcome to Fernbrook Gardens!"]
    )
    expect(assistant.config['legacy_behaviour']).to eq(behaviour)
  end

  it 'skips text that was not in use' do
    assistant.update_columns(config: assistant.config.merge('agent_role' => 'sales', 'greeting_mode' => 'ai')) # rubocop:disable Rails/SkipsModelValidations

    migration.up

    expect(assistant.reload.response_guidelines).to eq(['Mention free returns.'])
    expect(assistant.config).not_to have_key('legacy_behaviour')
  end

  it 'folds each text only once' do
    2.times { migration.up }

    expect(assistant.reload.response_guidelines.size).to eq(3)
  end

  it 'restores the instructions and the old values on down' do
    migration.up
    assistant.reload.update_columns(config: assistant.config.merge('agent_role_prompt' => '')) # rubocop:disable Rails/SkipsModelValidations

    migration.down
    assistant.reload

    expect(assistant.response_guidelines).to eq(['Mention free returns.'])
    expect(assistant.config).to include(behaviour)
    expect(assistant.config).not_to have_key('legacy_behaviour')
  end
end

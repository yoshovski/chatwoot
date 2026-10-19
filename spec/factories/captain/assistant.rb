FactoryBot.define do
  factory :captain_assistant, class: 'Captain::Assistant' do
    sequence(:name) { |n| "Assistant #{n}" }
    description { 'Test description' }
    # Existing regression fixtures model legacy agents; new-agent setup is checked separately.
    config { { 'knowledge_processing_version' => 1 } }
    association :account
  end
end

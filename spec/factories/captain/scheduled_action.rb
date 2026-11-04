FactoryBot.define do
  factory :captain_scheduled_action, class: 'Captain::ScheduledAction' do
    conversation
    account { conversation.account }
    assistant { association :captain_assistant, account: conversation.account }
    kind { 'follow_up_message' }
    due_at { 15.minutes.from_now }
    payload { { 'template' => 'Did the plan comparison help?' } }
  end
end

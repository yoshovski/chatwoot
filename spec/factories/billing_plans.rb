FactoryBot.define do
  factory :billing_plan do
    sequence(:name) { |n| "Plan #{n}" }
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory :account do
    sequence(:name) { |n| "Account #{n}" }
    status { 'active' }
    domain { 'test.com' }
    support_email { 'support@test.com' }

    # Like every account that existed before the AI limit applied in all states, a test account is a manual account
    # set in Super Admin, so specs that are not about billing keep AI replies. Pass `manual_ai_access: false` for an
    # account that has no subscription at all (a new signup).
    transient do
      manual_ai_access { true }
    end

    after(:create) do |account, evaluator|
      next if !evaluator.manual_ai_access || account.account_subscription

      account.create_account_subscription!(quota_anchor: Time.current, manual_ai_access: true)
    end
  end
end

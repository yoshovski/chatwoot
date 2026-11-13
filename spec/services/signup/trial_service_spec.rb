require 'rails_helper'

RSpec.describe Signup::TrialService do
  let!(:free) { create(:billing_plan, name: 'Free', ai_conversations_limit: 0) }
  let!(:growth) { create(:billing_plan, name: 'Growth', ai_conversations_limit: 150, signup_default: true, after_trial_plan: free) }
  let(:account) { create(:account) }
  let!(:signup) { AccountSignup.create!(account: account, email: 'anna@gmail.com') }
  let(:other_account) { create(:account) }

  before do
    AccountSignup.create!(account: other_account, email_domain: 'shop.example', trial_granted: true)
    described_class.new(account).start!
  end

  describe '#website_changed!' do
    it 'moves a trial to the plan after the trial when the website already had a trial' do
      account.update!(custom_attributes: account.custom_attributes.merge('website' => 'https://www.shop.example'))

      expect(account.reload.account_subscription).to have_attributes(billing_plan: free, trial_enabled: false, payment_status: 'active')
      expect(signup.reload).to have_attributes(website_domain: 'shop.example', trial_granted: false, trial_refused_reason: 'website_used')
    end

    it 'keeps the trial for a website no one else had' do
      account.update!(custom_attributes: account.custom_attributes.merge('website' => 'https://new.example'))

      expect(account.reload.account_subscription.billing_plan).to eq(growth)
      expect(signup.reload).to have_attributes(website_domain: 'new.example', trial_granted: true)
    end
  end

  describe '#grant!' do
    before do
      account.update!(custom_attributes: account.custom_attributes.merge('website' => 'https://shop.example'))
      described_class.new(account.reload).grant!
    end

    it 'starts the signup trial from today' do
      subscription = account.reload.account_subscription
      expect(subscription).to have_attributes(billing_plan: growth, trial_enabled: true, payment_status: 'trialing')
      expect(subscription.trial_ends_at).to be > 13.days.from_now
      expect(signup.reload).to have_attributes(trial_granted: true, trial_refused_reason: nil)
      expect(signup.trial_override_at).to be_present
    end

    it 'is not taken away by a later website' do
      account.update!(custom_attributes: account.custom_attributes.merge('website' => 'https://www.shop.example/again'))
      AccountSignup.create!(account: create(:account), website_domain: 'shop2.example', trial_granted: true)
      account.update!(custom_attributes: account.custom_attributes.merge('website' => 'https://shop2.example'))

      expect(account.reload.account_subscription.billing_plan).to eq(growth)
    end
  end
end

require 'rails_helper'

RSpec.describe AccountSubscription do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:plan) { create(:billing_plan, ai_conversations_limit: 500, trial_ai_conversations_limit: 2, trial_days: 7, agents_limit: 3) }
  let(:subscription) { account.subscription_settings }

  before { create(:agent_bot_inbox, inbox: inbox) }

  def open_window(started_at)
    conversation = create(:conversation, account: account, inbox: inbox)
    account.conversation_usage_windows.create!(conversation: conversation, started_at: started_at, ends_at: started_at + 24.hours,
                                               quota_period_start: subscription.quota_period(at: started_at).first)
  end

  describe 'limits from the plan' do
    it 'uses the plan limit unless the account sets its own' do
      account.update!(subscription_settings: { billing_plan_id: plan.id })
      expect(subscription.effective_limit).to eq(500)

      subscription.update!(monthly_limit: 40)
      expect(subscription.effective_limit).to eq(40)
    end

    it 'starts the trial with the plan trial length' do
      account.update!(subscription_settings: { billing_plan_id: plan.id, trial_enabled: true })

      expect(subscription.trial_ends_at).to be_within(1.minute).of(7.days.from_now)
    end
  end

  describe 'trial cap' do
    before { account.update!(subscription_settings: { billing_plan_id: plan.id, trial_enabled: true }) }

    it 'counts AI conversations over the whole trial, not the month' do
      subscription.update!(quota_anchor: 2.months.ago)
      open_window(40.days.ago)
      open_window(1.hour.ago)

      expect(subscription.consumed).to eq(2)
      expect(subscription.product_usage[:ai_conversations]).to eq(used: 2, limit: 2, period: 'trial')
      expect(account.ai_reply_allowed?).to be(false)
    end

    it 'lets the last allowed conversation finish its window' do
      open_window(2.hours.ago)
      window = open_window(1.hour.ago)

      expect(account.ai_reply_allowed?(window.conversation)).to be(true)
    end

    it 'returns to the monthly plan limit once paid' do
      subscription.update!(payment_status: 'active')

      expect(subscription.product_usage[:ai_conversations]).to include(limit: 500, period: 'month')
    end
  end

  describe 'AI conversation unit' do
    it 'counts incoming messages only in inboxes where a bot answers' do
      human_inbox = create(:inbox, account: account)
      create(:message, account: account, inbox: inbox, conversation: create(:conversation, account: account, inbox: inbox),
                       message_type: :incoming)
      create(:message, account: account, inbox: human_inbox, conversation: create(:conversation, account: account, inbox: human_inbox),
                       message_type: :incoming)

      expect(account.conversation_usage_windows.count).to eq(1)
    end
  end

  describe '#usage_summary' do
    it 'includes the plan and the daily conversation count' do
      account.update!(subscription_settings: { billing_plan_id: plan.id })
      create(:conversation, account: account, inbox: inbox)

      summary = subscription.usage_summary
      expect(summary[:plan]).to include(name: plan.name)
      expect(summary[:daily_usage].last).to include(conversations: 1)
    end
  end
end

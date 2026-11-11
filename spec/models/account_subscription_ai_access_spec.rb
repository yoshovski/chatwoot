require 'rails_helper'

# One row per subscription state of the T01 table, each at, under and over the AI conversation limit.
RSpec.describe AccountSubscriptionAiAccess do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:plan) { create(:billing_plan, ai_conversations_limit: 3, trial_ai_conversations_limit: 2, trial_days: 7) }
  let(:subscription) { account.subscription_settings }
  # Conversations already opened this period: none, at the plan allowance of 3, and over it.
  let(:usage_levels) { [0, 3, 4] }

  before { create(:agent_bot_inbox, inbox: inbox) }

  def open_windows(count, started_at: 1.hour.ago)
    Array.new(count) do |index|
      start = started_at + index.seconds
      account.conversation_usage_windows.create!(conversation: create(:conversation, account: account, inbox: inbox), started_at: start,
                                                 ends_at: start + 24.hours, quota_period_start: subscription.quota_period(at: start).first)
    end
  end

  def subscribe(payment_status, **attributes)
    account.update!(subscription_settings: { billing_plan_id: plan.id })
    subscription.update!(payment_status: payment_status, stripe_subscription_id: 'sub_test', **attributes)
  end

  describe 'no subscription (a new signup)' do
    let(:account) { create(:account, manual_ai_access: false) }

    it 'has no AI and says there is no plan' do
      expect(account.account_subscription).to be_nil
      expect(account.ai_reply_allowed?).to be(false)
      expect(subscription.ai_pause_reason).to eq('no_plan')
      expect(subscription.usage_summary).to include(ai_replies_paused: true, ai_pause_reason: 'no_plan')
    end

    it 'keeps no AI once the first conversation creates the subscription row' do
      create(:message, account: account, inbox: inbox, conversation: create(:conversation, account: account, inbox: inbox),
                       message_type: :incoming)

      expect(account.reload.account_subscription).to have_attributes(payment_status: 'manual', manual_ai_access: false)
      expect(account.ai_reply_allowed?).to be(false)
    end
  end

  describe 'manual account set in Super Admin' do
    it 'keeps AI replies without a limit, as before' do
      subscription.update!(monthly_limit: 3)

      usage_levels.each do |count|
        account.conversation_usage_windows.delete_all
        windows = open_windows(count)
        expect(account.ai_reply_allowed?).to be(true)
        expect(account.ai_reply_allowed?(windows.last&.conversation)).to be(true)
      end
      expect(subscription.ai_pause_reason).to be_nil
    end

    it 'has no AI when Super Admin has not marked the account' do
      subscription.update!(manual_ai_access: false)

      expect(subscription.ai_pause_reason).to eq('no_plan')
    end
  end

  describe 'Stripe dispute' do
    it 'pauses AI in any state until Super Admin clears it' do
      subscription.update!(ai_paused_at: Time.current, ai_paused_reason: 'dispute')
      expect(subscription.ai_pause_reason).to eq('payment_failed')

      subscription.update!(ai_paused_at: nil, ai_paused_reason: nil)
      expect(subscription.ai_pause_reason).to be_nil
    end
  end

  describe 'trialing' do
    before { account.update!(subscription_settings: { billing_plan_id: plan.id, trial_enabled: true }) }

    it 'allows AI under the trial cap' do
      open_windows(1)

      expect(subscription.payment_status).to eq('trialing')
      expect(account.ai_reply_allowed?).to be(true)
    end

    it 'stops new conversations at the cap but lets the last admitted one finish' do
      windows = open_windows(2)

      expect(subscription.ai_pause_reason).to eq('limit_reached')
      expect(account.ai_reply_allowed?(windows.last.conversation)).to be(true)
    end

    it 'stops a conversation that opened over the cap' do
      windows = open_windows(3)

      expect(subscription.ai_pause_reason(windows.last.conversation)).to eq('limit_reached')
    end

    it 'stops AI when the trial has ended, even under the cap' do
      subscription.update!(trial_ends_at: 1.minute.ago)

      expect(subscription.ai_pause_reason).to eq('trial_ended')
    end
  end

  describe 'active' do
    before { subscribe('active') }

    it 'allows AI under the plan allowance' do
      open_windows(2)

      expect(subscription.ai_pause_reason).to be_nil
    end

    it 'stops new conversations at the allowance but lets the last admitted one finish' do
      windows = open_windows(3)

      expect(subscription.ai_pause_reason).to eq('limit_reached')
      expect(subscription.ai_pause_reason(windows.last.conversation)).to be_nil
    end

    it 'stops a conversation that opened over the allowance' do
      windows = open_windows(4)

      expect(subscription.ai_pause_reason(windows.third.conversation)).to be_nil
      expect(subscription.ai_pause_reason(windows.last.conversation)).to eq('limit_reached')
    end

    it 'counts only the current month' do
      subscription.update!(quota_anchor: 40.days.ago)
      open_windows(3, started_at: 35.days.ago)

      expect(subscription.ai_pause_reason).to be_nil
    end

    it 'has no AI on a plan without AI conversations (Free)' do
      subscription.billing_plan.update!(ai_conversations_limit: 0)

      expect(subscription.ai_pause_reason).to eq('no_plan')
    end
  end

  describe 'past_due' do
    before { subscribe('active') }

    it 'records when the first invoice failed and clears it when paid' do
      subscription.update!(payment_status: 'past_due')
      failed_at = subscription.past_due_since

      travel 1.day do
        subscription.update!(payment_status: 'past_due', updated_at: Time.current)
        expect(subscription.past_due_since).to eq(failed_at)
      end
      subscription.update!(payment_status: 'active')
      expect(subscription.past_due_since).to be_nil
    end

    it 'allows AI up to the allowance for 7 days' do
      subscription.update!(payment_status: 'past_due', past_due_since: 6.days.ago)
      expect(subscription.ai_pause_reason).to be_nil

      open_windows(3)
      expect(subscription.ai_pause_reason).to eq('limit_reached')
    end

    it 'counts the 7 days from the first failed invoice when Stripe reported it' do
      subscription.update!(payment_status: 'past_due', past_due_since: 1.day.ago, payment_failed_at: 8.days.ago)
      expect(subscription.ai_pause_reason).to eq('payment_failed')
    end

    it 'stops AI after 7 days at, under and over the allowance' do
      subscription.update!(payment_status: 'past_due', past_due_since: 8.days.ago)

      usage_levels.each do |count|
        account.conversation_usage_windows.delete_all
        open_windows(count)
        expect(subscription.ai_pause_reason).to eq('payment_failed')
      end
    end
  end

  {
    'paused' => 'paused',
    'unpaid' => 'payment_failed',
    'incomplete' => 'payment_failed',
    'canceled' => 'no_plan',
    'incomplete_expired' => 'no_plan'
  }.each do |status, reason|
    describe status do
      before { subscribe(status) }

      it "stops AI at, under and over the allowance (#{reason})" do
        usage_levels.each do |count|
          account.conversation_usage_windows.delete_all
          windows = open_windows(count)
          expect(subscription.ai_pause_reason).to eq(reason)
          expect(account.ai_reply_allowed?(windows.last&.conversation)).to be(false)
        end
      end
    end
  end

  describe 'trial ended without a plan being paid' do
    it 'says the trial ended when Stripe cancels the trial subscription' do
      account.update!(subscription_settings: { billing_plan_id: plan.id, trial_enabled: true })
      subscription.update!(payment_status: 'canceled', stripe_subscription_id: 'sub_test')

      expect(subscription.ai_pause_reason).to eq('trial_ended')
    end
  end

  describe 'AI messages' do
    let(:conversation) { create(:conversation, account: account, inbox: inbox) }

    it 'rejects an AI agent reply while AI is paused, but not a reply from the team' do
      subscribe('paused')
      bot_reply = build(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing,
                                  sender: create(:agent_bot))

      expect(bot_reply).not_to be_valid
      expect(build(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing)).to be_valid
    end
  end
end

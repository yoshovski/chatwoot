require 'rails_helper'

RSpec.describe Onboarding::FirstWeekEmailsService do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account, role: :administrator) }
  let(:welcome_at) { Time.zone.parse('2026-11-10 14:00') }
  let!(:signup) { AccountSignup.create!(account: account, user: owner, email: owner.email, welcome_sent_at: welcome_at) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:growth) { create(:billing_plan, name: 'Growth', ai_conversations_limit: 100, trial_ai_conversations_limit: 50) }
  let(:sent) { [] }

  before do
    delivery = instance_double(ActionMailer::MessageDelivery, deliver_later: true)
    mailer = double
    allow(Onboarding::FirstWeekMailer).to receive(:with).with(account: account).and_return(mailer)
    allow(mailer).to receive(:notify) do |account_user, kind, meta|
      sent << [account_user.user, kind, meta]
      delivery
    end
  end

  def run_on(day, hours: 1)
    described_class.new(signup.reload, now: welcome_at + day.days + hours.hours).deliver_due
  end

  def kinds
    sent.map(&:second)
  end

  def unanswered_gap(question, count: 2)
    Captain::KnowledgeGap.create!(assistant: assistant, question: question, normalized_question: question.downcase, kind: :knowledge,
                                  classified_at: Time.current, occurrences_count: count, last_seen_at: Time.current)
  end

  def start_trial
    AccountSubscription.find_or_initialize_by(account: account)
                       .update!(billing_plan: growth, enabled: true, trial_enabled: true, payment_status: 'trialing',
                                trial_ends_at: welcome_at + 14.days)
  end

  describe 'day 1' do
    it 'sends the install email with the widget code while the widget is not on the site' do
      create(:channel_widget, account: account)

      run_on(1)

      expect(kinds).to eq(['onboarding_day_1'])
      expect(sent.first.last['script']).to start_with("<script>\n  (function(d,t) {").and include('websiteToken')
    end

    it 'is skipped once the widget is installed' do
      inbox = create(:channel_widget, account: account).inbox
      create(:conversation, account: account, inbox: inbox)

      run_on(1)

      expect(kinds).to be_empty
    end

    it 'is not due before day 1, and not any more two days after it' do
      run_on(0, hours: 23)
      run_on(3)

      expect(kinds).not_to include('onboarding_day_1')
    end
  end

  describe 'day 3' do
    it 'lists the rewritten unanswered questions, most asked first' do
      unanswered_gap('Do you ship to Switzerland?', count: 2)
      unanswered_gap('Can your generator power a DJI T50?', count: 5)

      run_on(3)

      _, kind, meta = sent.find { |_, k, _| k == 'onboarding_day_3' }
      expect(kind).to eq('onboarding_day_3')
      expect(meta).to include('count' => 2, 'assistant_id' => assistant.id,
                              'questions' => ['Can your generator power a DJI T50?', 'Do you ship to Switzerland?'])
    end

    it 'is skipped when there are no rewritten unanswered questions' do
      unanswered_gap('Seen once', count: 1)
      unanswered_gap('Not rewritten yet').update!(classified_at: nil)
      unanswered_gap('Answered').update!(status: :answered)

      run_on(3)

      expect(kinds).not_to include('onboarding_day_3')
    end
  end

  describe 'day 7' do
    it 'sends the trial date and usage while the account is still on its trial' do
      start_trial

      run_on(7)

      _, _, meta = sent.find { |_, k, _| k == 'onboarding_day_7' }
      expect(meta).to include('ends_at' => welcome_at + 14.days, 'used' => 0, 'limit' => 50)
    end

    it 'is skipped when there is no trial or it has turned paid' do
      run_on(7)
      start_trial
      account.subscription_settings.update!(payment_status: 'active')
      run_on(7)

      expect(kinds).not_to include('onboarding_day_7')
    end
  end

  describe 'every day' do
    before { create(:channel_widget, account: account) }

    it 'sends each email once however often the job runs' do
      3.times { run_on(1) }
      run_on(1, hours: 20)

      expect(kinds).to eq(['onboarding_day_1'])
      expect(BillingNotification.where(account: account, kind: 'onboarding_day_1', key: signup.id.to_s).count).to eq(1)
    end

    it 'sends nothing after the person unsubscribed or left the account' do
      account.account_users.find_by(user: owner).update!(onboarding_emails: false)
      run_on(1)
      account.account_users.find_by(user: owner).destroy!
      run_on(1)

      expect(kinds).to be_empty
    end

    it 'sends nothing to a suspended account' do
      account.update!(status: :suspended)

      run_on(1)

      expect(kinds).to be_empty
    end
  end

  describe '.candidates' do
    it 'covers signups whose welcome went out in the last 9 days' do
      old = AccountSignup.create!(account: create(:account), user: owner, email: 'a@b.c', welcome_sent_at: welcome_at - 10.days)
      unwelcomed = AccountSignup.create!(account: create(:account), user: owner, email: 'd@e.f')

      ids = described_class.candidates(now: welcome_at + 7.days).ids

      expect(ids).to include(signup.id)
      expect(ids).not_to include(old.id, unwelcomed.id)
    end
  end
end

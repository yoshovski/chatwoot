require 'rails_helper'

RSpec.describe Billing::NotificationsService do
  let(:account) { create(:account) }
  let!(:admin) { create(:user, account: account, role: :administrator) }
  let(:growth) { create(:billing_plan, name: 'Growth', ai_conversations_limit: 10, trial_ai_conversations_limit: 5) }
  let(:subscription) do
    AccountSubscription.find_or_initialize_by(account: account).tap { |record| record.update!(billing_plan: growth, payment_status: 'active') }
  end
  let(:mailer) { instance_double(ActionMailer::MessageDelivery, deliver_later: true) }
  let(:sent) { [] }

  before do
    create(:user, account: account, role: :agent)
    mailer_with = double(notify: mailer) # rubocop:disable RSpec/VerifiedDoubles
    allow(Billing::NotificationMailer).to receive(:with).and_return(mailer_with)
    allow(mailer_with).to receive(:notify) do |account_user, kind, meta|
      sent << [account_user.user, kind, meta]
      mailer
    end
  end

  def open_windows(count)
    count.times do
      account.conversation_usage_windows.create!(started_at: Time.current, ends_at: 1.day.from_now,
                                                 quota_period_start: subscription.quota_period.first)
    end
  end

  describe 'sent once' do
    it 'sends a due email to each administrator once however often it runs' do
      open_windows(8)

      2.times { described_class.new(subscription).deliver_due }

      expect(sent.map { |user, kind, _| [user, kind] }).to eq([[admin, 'usage_80']])
      expect(BillingNotification.find_by(account: account, kind: 'usage_80').recipients_count).to eq(1)
    end

    it 'sends 100 % after 80 % in the same period, and 80 % again in the next one' do
      open_windows(8)
      described_class.new(subscription).deliver_due
      open_windows(2)
      described_class.new(subscription).deliver_due
      travel_to(subscription.quota_period.last + 1.day) do
        open_windows(8)
        described_class.new(subscription).deliver_due
      end

      expect(sent.map(&:second)).to eq(%w[usage_80 usage_100 usage_80])
    end

    it 'says nothing about usage while extra conversations are left' do
      open_windows(10)
      ExtraAiConversationEntry.credit!(account: account, amount: 5, reason: 'adjustment', note: 'gift')

      described_class.new(subscription).deliver_due

      expect(sent).to be_empty
    end
  end

  describe 'opt-out' do
    it 'skips administrators who opted out of usage emails, and only those emails' do
      account.account_users.find_by(user: admin).update!(billing_usage_emails: false)
      open_windows(10)
      subscription.update!(auto_top_up_failed_at: 1.hour.ago)

      described_class.new(subscription).deliver_due

      expect(sent.map(&:second)).to eq(['auto_top_up_off'])
      expect(BillingNotification.find_by(account: account, kind: 'usage_100').recipients_count).to eq(0)
    end
  end

  describe 'failed payment' do
    before { subscription.update!(payment_status: 'past_due', payment_failed_at: Time.current) }

    it 'reminds on day 0, 3 and 6, then says the AI is paused on day 7' do
      kinds = [0, 1, 3, 6, 7, 8].flat_map do |day|
        sent.clear
        travel_to(subscription.payment_failed_at + day.days + 1.minute) { described_class.new(subscription.reload).deliver_due }
        sent.map(&:second)
      end

      expect(kinds).to eq(%w[payment_failed_0 payment_failed_3 payment_failed_6 payment_paused])
    end

    it 'stops reminding once the invoice is paid' do
      described_class.new(subscription).deliver_due
      subscription.update!(payment_status: 'active', payment_failed_at: nil)

      travel_to(3.days.from_now + 1.minute) { described_class.new(subscription.reload).deliver_due }

      expect(sent.map(&:second)).to eq(['payment_failed_0'])
    end

    it 'does not send an old failure the first time it runs' do
      subscription.update!(payment_failed_at: 20.days.ago)

      described_class.new(subscription).deliver_due

      expect(sent).to be_empty
    end
  end

  describe 'trial' do
    let(:subscription) do
      AccountSubscription.find_or_initialize_by(account: account).tap { |record| record.update!(billing_plan: growth, trial_enabled: true) }
    end

    it 'sends the notices 3 days and 1 day before the end' do
      ends_at = subscription.trial_ends_at
      kinds = [4.days, 3.days, 2.days, 1.day].flat_map do |before|
        sent.clear
        travel_to(ends_at - before + 1.minute) { described_class.new(subscription.reload).deliver_due }
        sent.map(&:second)
      end

      expect(kinds).to eq(%w[trial_ending_3 trial_ending_1])
    end
  end

  describe 'cancellation and win-back' do
    let(:details) do
      { 'cancel_at' => 20.days.from_now.to_i, 'latest_invoice' => { 'status' => 'paid', 'total' => 4900 } }
    end

    before { subscription.update!(stripe_customer_id: 'cus_1', stripe_subscription_id: 'sub_1', stripe_subscription_details: details) }

    it 'confirms a cancellation once and sends the win-back 14 days after the end' do
      described_class.new(subscription).deliver_due
      described_class.new(subscription).deliver_due
      subscription.update!(payment_status: 'canceled', stripe_subscription_details: details.merge('ended_at' => 20.days.from_now.to_i))
      travel_to(34.days.from_now + 1.minute) { described_class.new(subscription.reload).deliver_due }

      expect(sent.map(&:second)).to eq(%w[cancellation_confirmed win_back])
      expect(sent.first.third).to include('plan' => 'Growth')
    end
  end

  it 'sends a receipt for a top-up paid through Stripe' do
    ExtraAiConversationEntry.credit!(account: account, amount: 50, stripe_reference: 'in_1')

    described_class.new(subscription).deliver_due

    expect(sent.map { |_, kind, meta| [kind, meta['count']] }).to eq([['top_up_receipt', 50]])
  end

  it 'tells the administrators the trial ended' do
    described_class.new(subscription).deliver_trial_ended(1.minute.ago)

    expect(sent.map(&:second)).to eq(['trial_ended'])
  end
end

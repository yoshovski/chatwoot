require 'rails_helper'

RSpec.describe 'Super Admin account billing', type: :request do
  let(:super_admin) { create(:super_admin) }
  let(:account) { create(:account, manual_ai_access: false) }
  let(:base) { "/super_admin/accounts/#{account.id}/billing" }
  let(:account_page) { "/super_admin/accounts/#{account.id}#billing" }
  let!(:subscription) do
    AccountSubscription.create!(account: account, enabled: true, payment_status: 'trialing', trial_enabled: true,
                                trial_ends_at: 2.days.from_now, quota_anchor: 1.day.ago, stripe_customer_id: 'cus_1')
  end

  before { sign_in(super_admin, scope: :super_admin) }

  def last_action
    Audited.audit_class.where(auditable: subscription).where.not(comment: nil).last
  end

  it 'shows the billing timeline with Stripe events, ledger rows and plan changes' do
    StripeEvent.create!(stripe_id: 'evt_1', event_type: 'invoice.paid', stripe_customer_id: 'cus_1', stripe_created_at: 1.hour.ago, payload: {})
    ExtraAiConversationEntry.credit!(account: account, amount: 5, reason: 'adjustment', user: super_admin, note: 'Goodwill')
    subscription.update!(payment_status: 'active')

    get "/super_admin/accounts/#{account.id}"

    expect(response.body).to include('invoice.paid', 'adjustment +5', 'Goodwill', 'payment status trialing → active')
    expect(response.body).to include(I18n.t('super_admin.account_billing.replay_event'))
  end

  describe 'give the trial anyway' do
    let!(:free) { create(:billing_plan, name: 'Free', ai_conversations_limit: 0) }
    let!(:growth) { create(:billing_plan, name: 'Growth', ai_conversations_limit: 150, signup_default: true, after_trial_plan: free) }

    before do
      subscription.update!(billing_plan: free, trial_enabled: false, payment_status: 'active', stripe_customer_id: nil)
      AccountSignup.create!(account: account, email_domain: 'shop.example', trial_refused_reason: 'domain_used')
    end

    it 'starts the signup trial for a signup that was refused it, and logs who did it' do
      get "/super_admin/accounts/#{account.id}"
      expect(response.body).to include(I18n.t('super_admin.account_billing.grant_trial'))

      post "#{base}/grant_trial"

      expect(response).to redirect_to(account_page)
      expect(subscription.reload).to have_attributes(billing_plan: growth, payment_status: 'trialing', trial_enabled: true)
      expect(account.account_signup.reload).to have_attributes(trial_granted: true)
      expect(last_action).to have_attributes(comment: 'super_admin.grant_trial', user_id: super_admin.id)
    end

    it 'refuses an account that already has its trial' do
      account.account_signup.update!(trial_granted: true)
      post "#{base}/grant_trial"

      expect(flash[:alert]).to eq(I18n.t('super_admin.account_billing.refused.trial_granted'))
    end
  end

  describe 'extend the trial' do
    it 'moves a local trial and logs who did it' do
      ends_at = subscription.trial_ends_at
      post "#{base}/extend_trial", params: { days: 5 }

      expect(response).to redirect_to(account_page)
      expect(subscription.reload.trial_ends_at).to be_within(1.second).of(ends_at + 5.days)
      expect(last_action).to have_attributes(comment: 'super_admin.extend_trial', user_id: super_admin.id)
    end

    it 'moves a trial Stripe runs in Stripe too' do
      subscription.update!(stripe_subscription_id: 'sub_1')
      allow(Stripe::Subscription).to receive(:update)

      post "#{base}/extend_trial", params: { days: 3 }

      expect(Stripe::Subscription).to have_received(:update).with('sub_1', hash_including(trial_end: subscription.reload.trial_ends_at.to_i))
    end

    it 'refuses an account that is not in a trial' do
      subscription.update!(payment_status: 'active', trial_enabled: false)
      post "#{base}/extend_trial", params: { days: 5 }

      expect(flash[:alert]).to eq(I18n.t('super_admin.account_billing.refused.no_trial'))
    end
  end

  describe 'add extra conversations' do
    it 'writes a ledger row with the person and the reason' do
      post "#{base}/add_extra_conversations", params: { amount: 20, note: 'Outage on Nov 10' }

      entry = account.extra_ai_conversation_entries.last
      expect(entry).to have_attributes(reason: 'adjustment', amount: 20, remaining: 20, user_id: super_admin.id, note: 'Outage on Nov 10')
      expect(subscription.reload.extra_ai_conversations).to eq(20)
    end

    it 'requires a reason' do
      post "#{base}/add_extra_conversations", params: { amount: 20, note: ' ' }

      expect(account.extra_ai_conversation_entries).to be_empty
      expect(flash[:alert]).to eq(I18n.t('super_admin.account_billing.refused.note'))
    end
  end

  describe 'apply a coupon' do
    before { subscription.update!(payment_status: 'active', stripe_subscription_id: 'sub_1') }

    it 'adds the coupon to the Stripe subscription and logs it' do
      allow(Stripe::Subscription).to receive(:update)

      post "#{base}/apply_coupon", params: { coupon: 'WELCOME20' }

      expect(Stripe::Subscription).to have_received(:update).with('sub_1', discounts: [{ coupon: 'WELCOME20' }])
      expect(last_action.audited_changes).to eq('coupon' => 'WELCOME20')
    end

    it 'shows what Stripe refused' do
      allow(Stripe::Subscription).to receive(:update).and_raise(Stripe::InvalidRequestError.new('No such coupon', 'coupon'))

      post "#{base}/apply_coupon", params: { coupon: 'NOPE' }

      expect(flash[:alert]).to include('No such coupon')
      expect(last_action).to be_nil
    end
  end

  describe 'pause and resume the AI' do
    it 'stops AI replies until resumed, and logs both' do
      post "#{base}/pause_ai"

      expect(subscription.reload.ai_pause_reason).to eq('paused')
      expect(account.reload.ai_reply_allowed?).to be(false)

      post "#{base}/resume_ai"

      expect(subscription.reload.ai_paused_at).to be_nil
      expect(Audited.audit_class.where(auditable: subscription).pluck(:comment).compact).to eq(%w[super_admin.pause_ai super_admin.resume_ai])
    end

    it 'lifts a pause from a Stripe dispute' do
      subscription.update!(ai_paused_at: 1.day.ago, ai_paused_reason: 'dispute')

      post "#{base}/resume_ai"

      expect(subscription.reload.ai_paused_at).to be_nil
      expect(last_action.audited_changes).to eq('paused_for' => 'dispute')
    end
  end

  describe 'replay a webhook event' do
    it 'runs a stored event of this account again' do
      event = StripeEvent.create!(stripe_id: 'evt_1', event_type: 'invoice.paid', stripe_customer_id: 'cus_1', status: 'failed', payload: {})
      service = instance_double(Enterprise::Billing::ReplayStripeEventService, perform: event)
      allow(Enterprise::Billing::ReplayStripeEventService).to receive(:new).with(stripe_event: event).and_return(service)

      post "#{base}/replay_event", params: { stripe_event_id: event.id }

      expect(service).to have_received(:perform)
      expect(last_action.audited_changes).to include('stripe_event' => 'evt_1')
    end

    it 'refuses an event of another account' do
      other = StripeEvent.create!(stripe_id: 'evt_2', event_type: 'invoice.paid', stripe_customer_id: 'cus_other', payload: {})
      allow(Enterprise::Billing::ReplayStripeEventService).to receive(:new)

      post "#{base}/replay_event", params: { stripe_event_id: other.id }

      expect(Enterprise::Billing::ReplayStripeEventService).not_to have_received(:new)
      expect(flash[:alert]).to eq(I18n.t('super_admin.account_billing.refused.event'))
    end
  end
end

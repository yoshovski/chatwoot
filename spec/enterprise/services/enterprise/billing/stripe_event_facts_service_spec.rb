require 'rails_helper'

RSpec.describe Enterprise::Billing::StripeEventFactsService do
  let(:account) { create(:account) }
  let!(:subscription) do
    account.create_account_subscription!(quota_anchor: Time.current, enabled: true, stripe_customer_id: 'cus_facts',
                                         stripe_subscription_id: 'sub_facts', payment_status: 'active')
  end
  let(:created) { 2.days.ago.change(usec: 0) }

  def handle(type, object)
    described_class.new(build_stripe_event(type: type, object: object, created: created.to_i)).perform
    subscription.reload
  end

  describe 'invoice.payment_failed' do
    let(:invoice) { { id: 'in_failed', object: 'invoice', customer: 'cus_facts' } }

    before do
      allow(Stripe::Invoice).to receive(:retrieve).with('in_failed').and_return(Stripe::Invoice.construct_from(id: 'in_failed', status: 'open'))
    end

    it 'records the first failed invoice date and keeps it on later failures' do
      handle('invoice.payment_failed', invoice)
      expect(subscription.payment_failed_at).to eq(created)

      described_class.new(build_stripe_event(type: 'invoice.payment_failed', object: invoice, created: Time.current.to_i)).perform
      expect(subscription.reload.payment_failed_at).to eq(created)
    end

    it 'does not record a failure for an invoice that was paid since' do
      allow(Stripe::Invoice).to receive(:retrieve).with('in_failed').and_return(Stripe::Invoice.construct_from(id: 'in_failed', status: 'paid'))

      expect(handle('invoice.payment_failed', invoice).payment_failed_at).to be_nil
    end
  end

  describe 'invoice.payment_action_required' do
    it 'records when the customer was first asked to confirm the payment' do
      allow(Stripe::Invoice).to receive(:retrieve).with('in_sca').and_return(Stripe::Invoice.construct_from(id: 'in_sca', status: 'open'))

      expect(handle('invoice.payment_action_required', { id: 'in_sca', customer: 'cus_facts' }).payment_action_required_at).to eq(created)
    end
  end

  describe 'invoice.paid' do
    it 'clears the payment failure facts' do
      subscription.update!(payment_failed_at: 3.days.ago, payment_action_required_at: 3.days.ago)

      expect(handle('invoice.paid', { id: 'in_paid', customer: 'cus_facts' })).to have_attributes(payment_failed_at: nil,
                                                                                                  payment_action_required_at: nil)
    end
  end

  describe 'invoice.upcoming' do
    it 'records the next renewal date and never moves it back' do
      renews_at = 7.days.from_now.change(usec: 0)
      expect(handle('invoice.upcoming', { customer: 'cus_facts', next_payment_attempt: renews_at.to_i }).upcoming_invoice_at).to eq(renews_at)

      expect(handle('invoice.upcoming', { customer: 'cus_facts', next_payment_attempt: 1.month.ago.to_i }).upcoming_invoice_at).to eq(renews_at)
    end
  end

  describe 'customer.subscription.trial_will_end' do
    it 'records when Stripe announced the end of the trial' do
      object = { id: 'sub_facts', object: 'subscription', customer: 'cus_facts', trial_end: 3.days.from_now.to_i }

      expect(handle('customer.subscription.trial_will_end', object).trial_will_end_notified_at).to eq(created)
    end
  end

  describe 'checkout.session.expired' do
    it 'releases the expired checkout so the account can start a new one' do
      subscription.update!(stripe_checkout_session_id: 'cs_old')

      expect(handle('checkout.session.expired', { id: 'cs_old', customer: 'cus_facts', mode: 'subscription' }).stripe_checkout_session_id).to be_nil
    end

    it 'keeps a newer checkout' do
      subscription.update!(stripe_checkout_session_id: 'cs_new')

      expect(handle('checkout.session.expired', { id: 'cs_old', customer: 'cus_facts' }).stripe_checkout_session_id).to eq('cs_new')
    end
  end

  describe 'checkout.session.async_payment_failed' do
    it 'releases the checkout and re-reads the subscription from Stripe' do
      subscription.update!(stripe_checkout_session_id: 'cs_async')
      allow(Enterprise::Billing::AccountSubscriptionSyncService).to receive(:refresh)

      handle('checkout.session.async_payment_failed', { id: 'cs_async', customer: 'cus_facts', mode: 'subscription' })

      expect(subscription.stripe_checkout_session_id).to be_nil
      expect(Enterprise::Billing::AccountSubscriptionSyncService).to have_received(:refresh).with(account)
    end
  end

  describe 'charge.refunded' do
    it 're-reads the subscription from Stripe' do
      allow(Enterprise::Billing::AccountSubscriptionSyncService).to receive(:refresh)

      handle('charge.refunded', { id: 'ch_1', object: 'charge', customer: 'cus_facts', amount_refunded: 1900 })

      expect(Enterprise::Billing::AccountSubscriptionSyncService).to have_received(:refresh).with(account)
    end
  end

  describe 'charge.dispute.created' do
    let(:dispute) { { id: 'dp_1', object: 'dispute', charge: 'ch_disputed', amount: 4900, currency: 'eur', reason: 'fraudulent' } }
    let(:mailer) { instance_double(ActionMailer::MessageDelivery, deliver_later: true) }

    before do
      allow(Stripe::Charge).to receive(:retrieve).with('ch_disputed').and_return(Stripe::Charge.construct_from(id: 'ch_disputed',
                                                                                                               customer: 'cus_facts'))
      allow(AdministratorNotifications::BillingAlertMailer).to receive(:dispute_created).and_return(mailer)
    end

    it 'pauses the AI for the account and alerts Super Admin once' do
      handle('charge.dispute.created', dispute)
      handle('charge.dispute.created', dispute)

      expect(subscription).to have_attributes(ai_paused_at: created, ai_paused_reason: 'dispute')
      expect(subscription.ai_reply_allowed?).to be(false)
      expect(account.reload.ai_reply_allowed?).to be(false)
      expect(AdministratorNotifications::BillingAlertMailer).to have_received(:dispute_created)
        .with(account, hash_including(dispute_id: 'dp_1', amount_cents: 4900, reason: 'fraudulent')).once
    end
  end

  describe 'customer.deleted' do
    it 'unlinks the Stripe customer and ends the subscription' do
      handle('customer.deleted', { id: 'cus_facts', object: 'customer' })

      expect(subscription).to have_attributes(stripe_customer_id: nil, stripe_subscription_id: nil, payment_status: 'canceled')
    end

    it 'keeps a manual account manual' do
      subscription.update!(payment_status: 'manual')

      expect(handle('customer.deleted', { id: 'cus_facts', object: 'customer' }).payment_status).to eq('manual')
    end
  end

  it 'ignores an event for a customer without a subscription' do
    expect { handle('invoice.paid', { id: 'in_x', customer: 'cus_unknown' }) }.not_to(change { subscription.reload.attributes })
  end
end

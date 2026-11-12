require 'rails_helper'

RSpec.describe Enterprise::Billing::TopUpService do
  subject(:service) { described_class.new(account: account) }

  let(:account) { create(:account) }
  let(:plan) { create(:billing_plan, ai_conversations_limit: 100) }
  let(:subscription) { account.account_subscription }
  let(:draft) { Stripe::Invoice.construct_from(id: 'in_pack', status: 'draft') }
  let(:payment_method) { 'pm_card' }

  around { |example| with_modified_env(FRONTEND_URL: 'https://app.example.com') { example.run } }

  before do
    account.update!(subscription_settings: { billing_plan_id: plan.id, enabled: true })
    subscription.update!(stripe_customer_id: 'cus_top', stripe_subscription_id: 'sub_top', payment_status: 'active')
    allow(Stripe::Subscription).to receive(:retrieve).with('sub_top').and_return(
      Stripe::Subscription.construct_from(id: 'sub_top', default_payment_method: payment_method)
    )
    allow(Stripe::Customer).to receive(:retrieve).and_return(Stripe::Customer.construct_from(id: 'cus_top', invoice_settings: {}))
    allow(Stripe::PaymentMethod).to receive(:list).and_return(Stripe::ListObject.construct_from(data: []))
    allow(Stripe::Invoice).to receive(:create).and_return(draft)
    allow(Stripe::InvoiceItem).to receive(:create)
    allow(Stripe::Invoice).to receive(:finalize_invoice).and_return(Stripe::Invoice.construct_from(id: 'in_pack', status: 'open'))
    allow(Stripe::Invoice).to receive(:pay).and_return(Stripe::Invoice.construct_from(id: 'in_pack', status: 'paid'))
    allow(Stripe::Invoice).to receive(:void_invoice)
  end

  def use_ai_conversations(count)
    count.times do
      account.conversation_usage_windows.create!(started_at: Time.current, ends_at: 1.day.from_now,
                                                 quota_period_start: subscription.quota_period.first)
    end
  end

  def card_error(code)
    Stripe::CardError.new('Card problem', nil, code: code)
  end

  describe '#buy' do
    it 'charges the saved card off-session and leaves the credit to the webhook' do
      expect(service.buy(request_id: 'click-0001')).to eq(status: 'paid')

      expect(Stripe::Invoice).to have_received(:create).with(
        hash_including(customer: 'cus_top', default_payment_method: 'pm_card', automatic_tax: { enabled: true },
                       metadata: hash_including(chatoctave_top_up: '50', auto_top_up: 'false')),
        { idempotency_key: "top-up-#{account.id}-click-0001-invoice" }
      )
      expect(Stripe::InvoiceItem).to have_received(:create).with(hash_including(amount: 800, currency: 'eur'), anything)
      expect(Stripe::Invoice).to have_received(:pay).with('in_pack', { off_session: true },
                                                          { idempotency_key: "top-up-#{account.id}-click-0001-pay" })
      expect(subscription.extra_ai_conversations).to eq(0)
    end

    context 'without a saved card' do
      let(:payment_method) { nil }

      it 'opens Checkout, which saves the card for next time' do
        allow(Stripe::Checkout::Session).to receive(:create).and_return(Stripe::Checkout::Session.construct_from(url: 'https://checkout.stripe.test'))

        expect(service.buy).to eq(status: 'checkout', url: 'https://checkout.stripe.test')
        expect(Stripe::Checkout::Session).to have_received(:create).with(
          hash_including(mode: 'payment', payment_intent_data: { setup_future_usage: 'off_session' },
                         invoice_creation: hash_including(invoice_data: hash_including(metadata: hash_including(chatoctave_top_up: '50')))),
          anything
        )
        expect(Stripe::Invoice).not_to have_received(:create)
      end
    end

    it 'sends the customer to Stripe when the card asks for 3-D Secure (SCA)' do
      allow(Stripe::Invoice).to receive(:pay).and_raise(card_error('authentication_required'))
      allow(Stripe::Invoice).to receive(:retrieve).with('in_pack').and_return(
        Stripe::Invoice.construct_from(id: 'in_pack', hosted_invoice_url: 'https://invoice.stripe.test/pack')
      )

      expect(service.buy).to eq(status: 'action_required', url: 'https://invoice.stripe.test/pack')
      expect(Stripe::Invoice).not_to have_received(:void_invoice)
    end

    it 'voids the invoice when the card is declined' do
      allow(Stripe::Invoice).to receive(:pay).and_raise(card_error('card_declined'))

      expect { service.buy }.to raise_error(described_class::PaymentFailed)
      expect(Stripe::Invoice).to have_received(:void_invoice).with('in_pack')
    end

    it 'is not offered without a paid subscription' do
      subscription.update!(payment_status: 'canceled')

      expect { service.buy }.to raise_error(described_class::Unavailable)
    end
  end

  describe '#auto' do
    before { subscription.update!(auto_top_up_enabled: true, auto_top_up_max_packs: 2) }

    it 'does nothing while more than 5 AI conversations are left' do
      use_ai_conversations(94)

      service.auto

      expect(Stripe::Invoice).not_to have_received(:create)
    end

    it 'buys one pack when 5 are left, with a key per account and period step' do
      use_ai_conversations(95)

      service.auto

      step = "#{subscription.quota_period.first.to_i}-1"
      expect(Stripe::Invoice).to have_received(:create).with(hash_including(metadata: hash_including(auto_top_up: 'true')),
                                                             { idempotency_key: "auto-top-up-#{account.id}-#{step}-invoice" })
      expect(subscription.reload).to have_attributes(auto_top_up_count: 1, auto_top_up_pending_at: be_present)
    end

    it 'does not start a second pack while the first one is on its way' do
      use_ai_conversations(95)

      2.times { service.auto }

      expect(Stripe::Invoice).to have_received(:create).once
    end

    it 'stops at the monthly ceiling' do
      use_ai_conversations(100)
      subscription.update!(auto_top_up_period_start: subscription.quota_period.first, auto_top_up_count: 2)

      service.auto

      expect(Stripe::Invoice).not_to have_received(:create)
    end

    it 'starts counting again in the next period' do
      use_ai_conversations(100)
      subscription.update!(auto_top_up_period_start: subscription.quota_period.first - 1.month, auto_top_up_count: 2)

      service.auto

      expect(subscription.reload).to have_attributes(auto_top_up_count: 1, auto_top_up_period_start: subscription.quota_period.first)
    end

    it 'switches itself off when the off-session payment is declined' do
      use_ai_conversations(100)
      allow(Stripe::Invoice).to receive(:pay).and_raise(card_error('card_declined'))

      service.auto

      expect(Stripe::Invoice).to have_received(:void_invoice).with('in_pack')
      expect(subscription.reload).to have_attributes(auto_top_up_enabled: false, auto_top_up_pending_at: nil)
      expect(subscription.auto_top_up_failed_at).to be_present
    end

    it 'switches itself off when the card asks for 3-D Secure (SCA): nobody is there to confirm it' do
      use_ai_conversations(100)
      allow(Stripe::Invoice).to receive(:pay).and_raise(card_error('authentication_required'))

      service.auto

      expect(subscription.reload.auto_top_up_enabled).to be(false)
    end
  end
end

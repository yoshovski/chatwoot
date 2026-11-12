require 'rails_helper'

# T07: packs are credited only from the webhook, once per payment, keyed by the pack's invoice id.
RSpec.describe Enterprise::Billing::TopUpEventService do
  let(:account) { create(:account, manual_ai_access: false) }
  let!(:subscription) do
    account.create_account_subscription!(quota_anchor: Time.current, enabled: true, stripe_customer_id: 'cus_top',
                                         stripe_subscription_id: 'sub_top', payment_status: 'active')
  end
  let(:pack_metadata) { { chatoctave_top_up: '50', chatoctave_account_id: account.id.to_s, auto_top_up: 'false' } }
  let(:invoice) { { id: 'in_pack', object: 'invoice', customer: 'cus_top', metadata: pack_metadata } }

  def deliver(type, object)
    Enterprise::Billing::HandleStripeEventService.new.perform(event: build_stripe_event(type: type, object: object))
  end

  def paid_invoice(id = 'in_pack', metadata = pack_metadata)
    Stripe::Invoice.construct_from(id: id, status: 'paid', metadata: metadata)
  end

  before do
    allow(Stripe::Invoice).to receive(:retrieve).with('in_pack').and_return(paid_invoice)
    allow(Enterprise::Billing::AccountSubscriptionSyncService).to receive(:refresh)
  end

  it 'credits one pack when the same invoice.paid arrives twice' do
    2.times { deliver('invoice.paid', invoice) }

    expect(account.extra_ai_conversation_entries.where(reason: 'purchase').pluck(:amount, :stripe_reference)).to eq([[50, 'in_pack']])
    expect(subscription.extra_ai_conversations).to eq(50)
  end

  it 'credits a Checkout purchase once, whether checkout.session.completed or invoice.paid comes first' do
    session = { id: 'cs_pack', object: 'checkout.session', customer: 'cus_top', mode: 'payment', metadata: pack_metadata }
    allow(Stripe::Checkout::Session).to receive(:retrieve).with('cs_pack').and_return(
      Stripe::Checkout::Session.construct_from(id: 'cs_pack', payment_status: 'paid', invoice: 'in_pack', metadata: pack_metadata)
    )

    deliver('checkout.session.completed', session)
    deliver('invoice.paid', invoice)

    expect(account.extra_ai_conversation_entries.where(reason: 'purchase').count).to eq(1)
    expect(subscription.extra_ai_conversations).to eq(50)
  end

  it 'credits nothing while the payment is not complete' do
    allow(Stripe::Invoice).to receive(:retrieve).with('in_pack').and_return(Stripe::Invoice.construct_from(id: 'in_pack', status: 'open'))

    deliver('invoice.paid', invoice)

    expect(subscription.extra_ai_conversations).to eq(0)
  end

  it 'ignores a pack whose metadata names another account' do
    deliver('invoice.paid', invoice.merge(metadata: pack_metadata.merge(chatoctave_account_id: '0')))

    expect(subscription.extra_ai_conversations).to eq(0)
  end

  it 'leaves the subscription payment facts alone: a paid pack does not clear a failed renewal' do
    subscription.update!(payment_failed_at: 2.days.ago)

    deliver('invoice.paid', invoice)

    expect(subscription.reload.payment_failed_at).to be_present
    expect(Enterprise::Billing::AccountSubscriptionSyncService).not_to have_received(:refresh)
  end

  it 'does not record a pack that failed as a failed subscription payment' do
    deliver('invoice.payment_failed', invoice)

    expect(subscription.reload.payment_failed_at).to be_nil
  end

  context 'with an automatic pack' do
    let(:pack_metadata) { { chatoctave_top_up: '50', chatoctave_account_id: account.id.to_s, auto_top_up: 'true' } }

    before { subscription.update!(auto_top_up_enabled: true, auto_top_up_pending_at: 1.minute.ago) }

    it 'clears the in-flight mark when it is credited' do
      deliver('invoice.paid', invoice)

      expect(subscription.reload.auto_top_up_pending_at).to be_nil
      expect(subscription.extra_ai_conversations).to eq(50)
    end

    it 'switches auto top-up off when the payment fails later' do
      deliver('invoice.payment_failed', invoice)

      expect(subscription.reload).to have_attributes(auto_top_up_enabled: false, auto_top_up_pending_at: nil)
      expect(subscription.auto_top_up_failed_at).to be_present
    end
  end
end

require 'rails_helper'

RSpec.describe 'Enterprise::Webhooks::StripeController', type: :request do
  describe 'POST /enterprise/webhooks/stripe' do
    let(:params) { { content: 'hello' } }
    let(:event) { build_stripe_event(id: 'evt_1', type: 'customer.subscription.updated', object: { id: 'sub_1', customer: 'cus_1' }) }

    it 'call the Enterprise::Billing::HandleStripeEventService with the params' do
      handle_stripe = double
      allow(Stripe::Webhook).to receive(:construct_event).and_return(event)
      allow(Enterprise::Billing::HandleStripeEventService).to receive(:new).and_return(handle_stripe)
      allow(handle_stripe).to receive(:perform)
      perform_enqueued_jobs do
        post '/enterprise/webhooks/stripe', headers: { 'Stripe-Signature': 'test' }, params: params
      end
      expect(handle_stripe).to have_received(:perform).with(event: an_object_having_attributes(id: 'evt_1', type: event.type), replay: false)
    end

    it 'returns a bad request if the headers are missing' do
      post '/enterprise/webhooks/stripe', params: params
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns a bad request if the headers are invalid' do
      post '/enterprise/webhooks/stripe', headers: { 'Stripe-Signature': 'test' }, params: params
      expect(response).to have_http_status(:bad_request)
    end

    context 'with a verified event' do
      before { allow(Stripe::Webhook).to receive(:construct_event).and_return(event) }

      it 'stores the event, enqueues the job and answers 200 without doing the work in the request' do
        allow(Enterprise::Billing::HandleStripeEventService).to receive(:new)

        expect do
          post '/enterprise/webhooks/stripe', headers: { 'Stripe-Signature': 'test' }, params: params
        end.to have_enqueued_job(Enterprise::Billing::ProcessStripeEventJob)

        expect(response).to have_http_status(:ok)
        expect(Enterprise::Billing::HandleStripeEventService).not_to have_received(:new)
        expect(StripeEvent.find_by!(stripe_id: 'evt_1')).to have_attributes(event_type: 'customer.subscription.updated', status: 'received',
                                                                            stripe_customer_id: 'cus_1')
      end

      it 'answers 200 to a duplicate event without storing or enqueuing it again' do
        post '/enterprise/webhooks/stripe', headers: { 'Stripe-Signature': 'test' }, params: params

        expect do
          post '/enterprise/webhooks/stripe', headers: { 'Stripe-Signature': 'test' }, params: params
        end.not_to have_enqueued_job(Enterprise::Billing::ProcessStripeEventJob)

        expect(response).to have_http_status(:ok)
        expect(StripeEvent.where(stripe_id: 'evt_1').count).to eq(1)
      end
    end

    it 'does not store an event whose signature does not verify' do
      allow(Stripe::Webhook).to receive(:construct_event).and_raise(Stripe::SignatureVerificationError.new('bad', 'sig'))

      post '/enterprise/webhooks/stripe', headers: { 'Stripe-Signature': 'forged' }, params: params

      expect(response).to have_http_status(:bad_request)
      expect(StripeEvent.count).to eq(0)
    end

    it 'stores an unknown event type as ignored and answers 200 without a job' do
      unknown = build_stripe_event(id: 'evt_unknown', type: 'radar.early_fraud_warning.created', object: { id: 'issfr_1' })
      allow(Stripe::Webhook).to receive(:construct_event).and_return(unknown)

      expect do
        post '/enterprise/webhooks/stripe', headers: { 'Stripe-Signature': 'test' }, params: params
      end.not_to have_enqueued_job(Enterprise::Billing::ProcessStripeEventJob)

      expect(response).to have_http_status(:ok)
      expect(StripeEvent.find_by!(stripe_id: 'evt_unknown')).to have_attributes(status: 'ignored', processed_at: be_present)
    end
  end
end

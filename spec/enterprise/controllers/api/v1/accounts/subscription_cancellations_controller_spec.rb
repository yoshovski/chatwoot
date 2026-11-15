require 'rails_helper'

RSpec.describe 'Subscription cancellation API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:service) do
    instance_double(Enterprise::Billing::CancellationService, start: { id: 1, discount_available: true, smaller_plans: [] },
                                                              decide: { status: 'canceled' }, keep: { status: 'kept' }, resume: { status: 'resumed' })
  end
  let(:path) { "/api/v1/accounts/#{account.id}/account_subscription/cancellations" }

  before { allow(Enterprise::Billing::CancellationService).to receive(:new).with(account: account, actor: admin).and_return(service) }

  it 'starts a cancellation for the current account and administrator' do
    post path, params: { reason: 'expensive' }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    expect(service).to have_received(:start).with(reason: 'expensive', feature: nil)
  end

  it 'allows skipping the reason' do
    post "#{path}/1/confirm", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    expect(service).to have_received(:decide).with(id: '1', action: 'confirm', reason: 'other', feature: nil)
  end

  it 'does not let an agent start a cancellation' do
    post path, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
    expect(service).not_to have_received(:start)
  end

  it 'does not let an administrator of another account cancel this plan' do
    outsider = create(:user, account: create(:account), role: :administrator)
    post "#{path}/1/confirm", headers: outsider.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
    expect(service).not_to have_received(:decide)
  end

  ['unknown', ['expensive'], 1].each do |reason|
    it "rejects invalid reason #{reason.inspect}" do
      post path, params: { reason: reason }, headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(service).not_to have_received(:start)
    end
  end

  it 'rejects a non-string or oversized feature request' do
    [1, 'x' * 2001].each do |feature|
      post "#{path}/1/confirm", params: { reason: 'feature', feature: feature }, headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
    expect(service).not_to have_received(:decide)
  end

  [nil, 0, 4, '2', [2]].each do |months|
    it "rejects invalid pause months #{months.inspect}" do
      post "#{path}/1/accept", params: { reason: 'unused', months: months }, headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(service).not_to have_received(:decide)
    end
  end

  it 'accepts a pause of three months' do
    post "#{path}/1/accept", params: { reason: 'unused', months: 3 }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    expect(service).to have_received(:decide).with(id: '1', action: 'accept', reason: 'unused', feature: nil, months: 3, plan: nil)
  end

  it 'rejects malformed plan ids' do
    post "#{path}/1/accept", params: { reason: 'feature', plan_id: [1] }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(service).not_to have_received(:decide)
  end

  it 'keeps a plan and resumes a paused plan' do
    post "#{path}/keep", headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body).to eq('status' => 'kept')
    post "#{path}/resume", headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body).to eq('status' => 'resumed')
  end

  it 'returns a useful failure for an unavailable offer' do
    allow(service).to receive(:decide).and_raise(Enterprise::Billing::AccountCheckoutService::Unavailable)
    post "#{path}/1/accept", params: { reason: 'expensive' }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to be_present
  end

  it 'does not expose Stripe error details' do
    allow(service).to receive(:start).and_raise(Stripe::APIConnectionError.new('internal Stripe context'))
    post path, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:bad_gateway)
    expect(response.body).not_to include('internal Stripe context')
  end
end

require 'rails_helper'

RSpec.describe 'Signup throttles', type: :request do
  let!(:store) { Rack::Attack.cache.store }

  before do
    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  after do
    Rack::Attack.enabled = false
    Rack::Attack.cache.store = store
  end

  it 'allows three signups an hour per business email domain, from any IP' do
    statuses = Array.new(4) do |n|
      post '/api/v1/accounts', params: { email: "person#{n}@shop.example" }, as: :json, headers: { 'REMOTE_ADDR' => "203.0.113.#{n + 1}" }
      response.status
    end

    expect(statuses.last).to eq(429)
    expect(statuses.first(3)).not_to include(429)
  end

  it 'leaves free-mail domains to the IP limits' do
    statuses = Array.new(4) do |n|
      post '/api/v2/accounts', params: { email: "person#{n}@gmail.com" }, as: :json, headers: { 'REMOTE_ADDR' => "203.0.113.#{n + 1}" }
      response.status
    end

    expect(statuses).not_to include(429)
  end

  it 'allows five signups per IP in 30 minutes on both signup endpoints' do
    statuses = Array.new(6) do |n|
      post(n.even? ? '/api/v1/accounts' : '/api/v2/accounts', params: { email: "p#{n}@gmail.com" }, as: :json,
                                                              headers: { 'REMOTE_ADDR' => '198.51.100.9' })
      response.status
    end

    expect(statuses.last).to eq(429)
  end
end

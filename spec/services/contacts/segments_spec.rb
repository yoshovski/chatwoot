require 'rails_helper'

RSpec.describe Contacts::Segments do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:service) { described_class.new(account, user) }
  let!(:visitor) { create(:contact, account: account, created_at: 10.days.ago) }
  let!(:lead) { create(:contact, :with_email, account: account, created_at: 2.days.ago) }
  let!(:customer) { create(:contact, :with_email, account: account, contact_type: :customer, created_at: 12.days.ago) }
  let!(:foreign) { create(:contact, :with_email) }

  before do
    allow(OnlineStatusTracker).to receive(:get_available_contact_ids).with(account.id).and_return([lead.id, foreign.id])
  end

  it 'computes account-scoped defaults and hides orders until order history exists' do
    counts = service.list.index_by { |item| item[:id] }
    expect(counts.keys).to eq(%w[all online leads new waiting])
    expect(counts.transform_values { |item| item[:count] }).to eq('all' => 3, 'online' => 1, 'leads' => 1, 'new' => 1, 'waiting' => 0)
    expect(service.scope('all')).to include(visitor)
    expect(account.custom_filters).to be_empty
    expect(service.valid_reference?('orders')).to be(false)
  end

  it 'includes a contact once when multiple open conversations wait for a reply' do
    create_list(:conversation, 2, account: account, contact: lead, waiting_since: 1.hour.ago)
    resolved = create(:conversation, account: account, contact: customer, status: :resolved)
    resolved.update!(waiting_since: 1.hour.ago)
    expect(service.scope('waiting').pluck(:id)).to eq([lead.id])
    expect(service.list.find { |item| item[:id] == 'waiting' }[:count]).to eq(1)
  end

  it 'uses the existing filter semantics for saved references and only lists the current user’s segments' do
    query = { payload: [{ attribute_key: 'email', filter_operator: 'equal_to', values: [lead.email], attribute_model: 'standard' }] }
    saved = create(:custom_filter, account: account, user: user, filter_type: :contact, query: query)
    other = create(:custom_filter, account: account, filter_type: :contact, query: query)
    expect(service.scope("custom:#{saved.id}").pluck(:id)).to eq([lead.id])
    expect(service.list.map { |item| item[:id] }).to include("custom:#{saved.id}")
    expect(service.list.map { |item| item[:id] }).not_to include("custom:#{other.id}")
  end

  it 'rejects foreign, conversation, and deleted segment references' do
    foreign_segment = create(:custom_filter, filter_type: :contact)
    conversation_segment = create(:custom_filter, account: account, user: user)
    expect(service.valid_reference?("custom:#{foreign_segment.id}")).to be(false)
    expect(service.valid_reference?("custom:#{conversation_segment.id}")).to be(false)
    expect(service.matches?('all', foreign)).to be(false)
    expect { service.scope("custom:#{foreign_segment.id}") }.to raise_error(ActiveRecord::RecordNotFound)
    expect(service.matches?('custom:999999999', lead)).to be(false)
  end
end

require 'rails_helper'

RSpec.describe AdministratorNotifications::BillingAlertMailer do
  let(:account) { create(:account, name: 'Test Store') }
  let(:details) { { dispute_id: 'dp_1', amount_cents: 4900, currency: 'eur', reason: 'fraudulent' } }

  before do
    allow(GlobalConfig).to receive(:get).and_call_original
    allow(GlobalConfig).to receive(:get).with('CHATWOOT_INSTANCE_ADMIN_EMAIL').and_return('CHATWOOT_INSTANCE_ADMIN_EMAIL' => 'admin@example.com')
    allow_any_instance_of(described_class).to receive(:smtp_config_set_or_development?).and_return(true) # rubocop:disable RSpec/AnyInstance
  end

  it 'tells the instance admin which account is paused and why' do
    mail = described_class.dispute_created(account, details)

    expect(mail.to).to eq(['admin@example.com'])
    expect(mail.subject).to eq("Payment dispute on account #{account.id}: AI paused")
    expect(mail.body.encoded).to include('dp_1', '49.00 EUR', 'fraudulent', "/super_admin/accounts/#{account.id}")
  end

  it 'sends nothing without an instance admin email' do
    allow(GlobalConfig).to receive(:get).with('CHATWOOT_INSTANCE_ADMIN_EMAIL').and_return({})

    expect(described_class.dispute_created(account, details).message).to be_a(ActionMailer::Base::NullMail)
  end
end

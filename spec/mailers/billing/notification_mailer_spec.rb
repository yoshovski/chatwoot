require 'rails_helper'

RSpec.describe Billing::NotificationMailer do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator, display_name: 'Ana') }
  let(:account_user) { account.account_users.find_by(user: admin) }

  before { allow_any_instance_of(described_class).to receive(:smtp_config_set_or_development?).and_return(true) } # rubocop:disable RSpec/AnyInstance

  def notify(kind, meta)
    described_class.with(account: account).notify(account_user, kind, meta)
  end

  it 'words a failed payment with its pause date and one button to Billing' do
    mail = notify('payment_failed_0', { 'plan' => 'Growth', 'pauses_at' => Time.zone.parse('2026-11-20 10:00') })

    expect(mail.to).to eq([admin.email])
    expect(mail.subject).to eq('We could not charge your card')
    expect(mail.body.encoded).to include('Hi Ana,', 'your Growth plan', '20 November 2026', 'Update card',
                                         "/app/accounts/#{account.id}/settings/billing")
    expect(mail.header['List-Unsubscribe']).to be_nil
  end

  it 'gives the usage emails a personal opt-out link' do
    mail = notify('usage_80', { 'used' => 40, 'limit' => 50, 'resets_at' => 10.days.from_now })

    expect(mail.subject).to eq('40 of 50 AI conversations used')
    token = CGI.unescape(mail.body.encoded[/usage_opt_out\?token=([^"]+)/, 1])
    expect(AccountUser.find_signed(token, purpose: :billing_usage_emails)).to eq(account_user)
    expect(mail.header['List-Unsubscribe-Post'].value).to eq('List-Unsubscribe=One-Click')
  end

  it 'offers plans instead of a top-up when the account cannot buy one' do
    mail = notify('usage_100', { 'used' => 5, 'limit' => 5, 'trial' => true, 'can_top_up' => false })

    expect(mail.body.encoded).to include('all 5 AI conversations in your trial', 'Choose a plan')
  end

  it 'names the charge when a paid trial converts' do
    mail = notify('trial_ending_3', { 'ends_at' => 3.days.from_now, 'plan' => 'Growth', 'paid_next' => true,
                                      'amount' => { 'cents' => 4900, 'currency' => 'eur' } })

    expect(mail.body.encoded).to include('your card is charged 49.00 EUR')
  end
end

require 'rails_helper'

RSpec.describe Signup::WelcomeJob do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let!(:signup) { AccountSignup.create!(account: account, user: user, email: user.email) }
  let(:delivery) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }

  it 'is queued when the person confirms their email' do
    user.update!(confirmed_at: nil)

    expect { user.confirm }.to have_enqueued_job(described_class).with(signup)
  end

  it 'sends the welcome once' do
    mailer = double(welcome: delivery) # rubocop:disable RSpec/VerifiedDoubles
    allow(Signup::WelcomeMailer).to receive(:with).with(account: account).and_return(mailer)

    2.times { described_class.perform_now(signup) }

    expect(delivery).to have_received(:deliver_now).once
    expect(signup.reload.welcome_sent_at).to be_present
  end

  it 'writes the welcome email with one next step' do
    allow_any_instance_of(Signup::WelcomeMailer).to receive(:smtp_config_set_or_development?).and_return(true) # rubocop:disable RSpec/AnyInstance
    mail = Signup::WelcomeMailer.with(account: account).welcome(user)

    expect(mail.to).to eq([user.email])
    expect(mail.subject).to start_with('Welcome to')
    expect(mail.body.encoded).to include("/app/accounts/#{account.id}/dashboard")
  end
end

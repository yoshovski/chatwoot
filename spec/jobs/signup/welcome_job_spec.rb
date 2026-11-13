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

  it 'sends the day-0 email once' do
    mailer = double(notify: delivery) # rubocop:disable RSpec/VerifiedDoubles
    allow(Onboarding::FirstWeekMailer).to receive(:with).with(account: account).and_return(mailer)

    2.times { described_class.perform_now(signup) }

    expect(mailer).to have_received(:notify).with(account.account_users.find_by(user: user), 'onboarding_day_0').once
    expect(signup.reload.welcome_sent_at).to be_present
  end
end

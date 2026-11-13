require 'rails_helper'

RSpec.describe Onboarding::FirstWeekMailer do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account, role: :administrator, display_name: 'Ana') }
  let(:account_user) { account.account_users.find_by(user: owner) }

  before { allow_any_instance_of(described_class).to receive(:smtp_config_set_or_development?).and_return(true) } # rubocop:disable RSpec/AnyInstance

  def notify(kind, meta = {})
    described_class.with(account: account).notify(account_user, kind, meta)
  end

  it 'sends day 0 with one next step, testing the agent, and an unsubscribe link' do
    mail = notify('onboarding_day_0')

    expect(mail.to).to eq([owner.email])
    expect(mail.subject).to start_with('Welcome to')
    expect(mail.body.encoded).to include('Hi Ana,', 'Test your agent', "/app/accounts/#{account.id}/home/setup/test_agent")
    token = CGI.unescape(mail.body.encoded[/opt_out\?token=([^"]+)/, 1])
    expect(AccountUser.find_signed(token, purpose: :onboarding_emails)).to eq(account_user)
    expect(mail.header['List-Unsubscribe-Post'].value).to eq('List-Unsubscribe=One-Click')
  end

  it 'puts the widget code in the day-1 email' do
    mail = notify('onboarding_day_1', { 'script' => '<script>websiteToken</script>' })

    expect(mail.subject).to eq('Put your AI agent on your website')
    expect(mail.body.encoded).to include('&lt;script&gt;websiteToken&lt;/script&gt;', 'Install', '/home/setup/chat_widget')
  end

  it 'lists the questions in the day-3 email and links to the suggestions' do
    mail = notify('onboarding_day_3', { 'count' => 4, 'assistant_id' => 7, 'questions' => ['Do you ship to Switzerland?'] })

    expect(mail.subject).to eq("4 questions your AI agent couldn't answer")
    expect(mail.body.encoded).to include('Do you ship to Switzerland?', 'Add answers', "/app/accounts/#{account.id}/captain/7/faqs/suggestions")
    expect(notify('onboarding_day_3', { 'count' => 1, 'questions' => ['Q'] }).subject).to eq("1 question your AI agent couldn't answer")
  end

  it 'gives the trial date and usage so far in the day-7 email' do
    ends_at = Time.zone.parse('2026-11-27 10:00')

    expect(notify('onboarding_day_7', { 'ends_at' => ends_at, 'used' => 23, 'limit' => 50 }).body.encoded)
      .to include('27 November 2026', 'answered 23 of the 50 conversations', 'See plans', '/settings/billing')
    expect(notify('onboarding_day_7', { 'ends_at' => ends_at, 'used' => 1 }).body.encoded).to include('answered 1 customer conversation.')
    expect(notify('onboarding_day_7', { 'ends_at' => ends_at, 'used' => 0 }).body.encoded).to include('has not answered a customer yet')
  end

  it "writes in the recipient's own language" do
    owner.update!(ui_settings: { 'locale' => 'es' })

    expect(notify('onboarding_day_3', { 'count' => 2, 'questions' => ['Q'] }).subject).to eq('2 preguntas que tu agente de IA no supo responder')
  end

  it 'keeps every text within 60 words' do
    %w[en es it].each do |locale|
      I18n.with_locale(locale) do
        I18n.t('onboarding_emails').except(:greeting, :opt_out).each_value do |texts|
          texts.except(:subject, :button).values.flat_map { |body| body.is_a?(Hash) ? body.values : [body] }.each do |body|
            expect(body.split.size).to be <= 60, "#{locale}: #{body}"
          end
        end
      end
    end
  end
end

# Decides which first-week email (T15) is due for one public signup and sends it to the person who signed up.
#
# Day 0 is the welcome, sent when the email address is confirmed (Signup::WelcomeJob); days 1, 3 and 7 count from
# that send. Each is skipped when its step is done (the widget is on the site, there are no unanswered questions,
# the trial is over) and sent once: BillingNotification, T08's sent-record table, keeps one row per kind and signup.
# A day is due for DUE_WINDOW, so a late run still sends it and an old signup never gets a stale one.
class Onboarding::FirstWeekEmailsService
  DAYS = { 'onboarding_day_1' => 1, 'onboarding_day_3' => 3, 'onboarding_day_7' => 7 }.freeze
  DUE_WINDOW = 2.days
  QUESTIONS_LIMIT = 3

  # Signups whose welcome went out recently enough for one of the days to be due.
  def self.candidates(now: Time.current)
    AccountSignup.where.not(account_id: nil).where(welcome_sent_at: (now - DAYS.values.max.days - DUE_WINDOW)..now)
  end

  def initialize(signup, now: Time.current)
    @signup = signup
    @account = signup.account
    @now = now
  end

  def deliver_due
    return unless account_user

    DAYS.each do |kind, day|
      next unless due?(day)

      meta = send(:"meta_#{kind.delete_prefix('onboarding_')}")
      next unless meta
      next unless BillingNotification.claim(@account, kind, @signup.id)

      Onboarding::FirstWeekMailer.with(account: @account).notify(account_user, kind, meta.compact).deliver_later
    end
  end

  private

  # The person who signed up, while they are still on the account, confirmed and not opted out.
  def account_user
    return @account_user if defined?(@account_user)

    @account_user = if @account&.active? && @signup.user&.confirmed?
                      @account.account_users.find_by(user_id: @signup.user_id, onboarding_emails: true)
                    end
  end

  def due?(day)
    at = @signup.welcome_sent_at + day.days
    at <= @now && at > @now - DUE_WINDOW
  end

  # Not sent once the widget is on the site.
  def meta_day_1
    return if Captain::HomeSummaryBuilder.widget_installed?(@account)

    { 'script' => widget_script }
  end

  # The install snippet of the first website inbox, without the indentation it has in the source.
  def widget_script
    lines = @account.inboxes.where(channel_type: 'Channel::WebWidget').order(:id).first&.channel&.web_widget_script.to_s.lines
    lines = lines.reject { |line| line.strip.empty? }
    indent = lines.map { |line| line[/\A */].size }.min
    lines.map { |line| line.delete_prefix(' ' * indent) }.join.rstrip.presence
  end

  # The rewritten questions from the Unanswered list (T18); not sent when there are none.
  def meta_day_3
    gaps = @account.captain_knowledge_gaps.unanswered.where.not(classified_at: nil)
    questions = gaps.ordered.limit(QUESTIONS_LIMIT).pluck(:question)
    return if questions.empty?

    { 'questions' => questions, 'count' => gaps.count, 'assistant_id' => gaps.ordered.pick(:assistant_id) }
  end

  # Only while the account is still on its trial.
  def meta_day_7
    subscription = @account.subscription_settings
    return unless subscription.trial_active? && subscription.trial_ends_at&.>(@now)

    { 'ends_at' => subscription.trial_ends_at, 'used' => subscription.consumed(at: @now),
      'limit' => (subscription.effective_limit if subscription.trial_capped?) }
  end
end

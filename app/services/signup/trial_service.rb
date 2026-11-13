# One trial per website domain (T11). A public signup whose business email domain already had a trial starts on the
# plan after the trial (Free); so does a trial whose account later sets a website that already had one. Super Admin
# can give the trial anyway (#grant!), and then a later website no longer takes it away.
class Signup::TrialService
  def initialize(account)
    @account = account
    @signup = account.account_signup
  end

  # AccountBuilder, inside the signup transaction.
  def start!
    plan = BillingPlan.for_signup
    return if plan.nil?

    if @signup.trial_domain_used?
      @signup.update!(trial_granted: false, trial_refused_reason: 'domain_used')
      start_after_trial_plan!(plan)
    else
      @signup.update!(trial_granted: true)
      @account.subscription_settings.update!(billing_plan: plan, trial_enabled: true)
    end
  end

  # The account set or changed its website (Account after commit).
  def website_changed!(url)
    domain = AccountSignup.website_domain(url)
    return if domain.blank? || domain == @signup.website_domain

    @signup.update!(website_domain: domain)
    return unless @signup.trial_granted? && @signup.trial_override_at.nil? && local_trial? && @signup.trial_domain_used?

    @account.with_lock do
      @signup.update!(trial_granted: false, trial_refused_reason: 'website_used')
      start_after_trial_plan!(subscription.billing_plan)
    end
  end

  # Super Admin override: the signup trial, from today, even though the domain already had one.
  def grant!
    plan = BillingPlan.for_signup
    raise ActiveRecord::RecordNotFound, 'No active signup plan' if plan.nil?

    @account.with_lock do
      @signup.update!(trial_granted: true, trial_refused_reason: nil, trial_override_at: Time.current)
      @account.subscription_settings.update!(billing_plan: plan, trial_enabled: true, trial_ends_at: nil, reset_usage: true)
    end
  end

  private

  def subscription
    @account.account_subscription
  end

  # A trial this installation runs: not yet a Stripe subscription.
  def local_trial?
    subscription&.payment_status == 'trialing' && subscription.stripe_subscription_id.blank?
  end

  # The same move EndTrialsJob makes when a trial ends.
  def start_after_trial_plan!(trial_plan)
    after = trial_plan&.after_trial_plan
    return if after.nil?

    @account.subscription_settings.update!(billing_plan: after, trial_enabled: false, payment_status: 'active', reset_usage: true)
  end
end

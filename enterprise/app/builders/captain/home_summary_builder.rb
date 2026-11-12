# Everything the Home page shows, in one request: the AI agent's state, the period's numbers (Captain::HomeActivityBuilder),
# what needs the owner (Captain::HomeNeedsBuilder), recent leads, usage with a forecast, and the setup checklist.
class Captain::HomeSummaryBuilder
  def initialize(account, user, period: Captain::HomeActivityBuilder::PERIODS.first, timezone_offset: nil)
    @account = account
    @user = user
    @period = period
    @timezone_offset = timezone_offset
  end

  def summary
    {
      status: status,
      site: site,
      **Captain::HomeActivityBuilder.new(account, period: period, timezone_offset: timezone_offset).activity,
      needs: needs_builder.needs,
      leads: needs_builder.leads,
      setup: setup_steps,
      project_status: project_status,
      usage: usage
    }
  end

  private

  attr_reader :account, :user, :period, :timezone_offset

  def needs_builder
    @needs_builder ||= Captain::HomeNeedsBuilder.new(account, user)
  end

  # live | learning | paused | limit_reached | needs_attention
  def status
    return 'limit_reached' if pause_reason == 'limit_reached'
    return 'paused' if pause_reason
    return 'needs_attention' if !setup_steps[:agent_inbox] || needs_builder.failed_syncs.any? || needs_builder.channel_problems.any?
    return 'learning' if account.captain_documents.sync_syncing.exists?

    'live'
  end

  # The website the chat widget is on, as a host name ("forma-store.com").
  def site
    url = Channel::WebWidget.where(account_id: account.id).where.not(website_url: [nil, '']).order(:id).pick(:website_url)
    url && (URI.parse(url).host || url).delete_prefix('www.')
  rescue URI::InvalidURIError
    url
  end

  def subscription
    @subscription ||= account.subscription_settings
  end

  def pause_reason
    return @pause_reason if defined?(@pause_reason)

    @pause_reason = subscription.ai_pause_reason
  end

  def setup_steps
    @setup_steps ||= {
      ai_agent: account.captain_assistants.exists?,
      knowledge: account.captain_assistant_responses.approved.exists? || account.captain_documents.exists?,
      agent_inbox: CaptainInbox.joins(:captain_assistant).exists?(captain_assistants: { account_id: account.id }),
      chat_widget: widget_installed?,
      mailbox: mailbox_connected?,
      teammate: account.account_users.count > 1
    }
  end

  def project_status
    {
      widget_installed: widget_installed?,
      mailbox_connected: mailbox_connected?,
      domain: domain_status
    }
  end

  # The same numbers as Billing (AccountSubscription#product_usage): AI conversations against the plan or Super Admin
  # limit (the trial cap during a capped trial), plus seats, inboxes and documents. An unset limit comes back as nil.
  def usage
    products = subscription.product_usage
    ai = products[:ai_conversations].slice(:used, :limit, :extra_left)
    products.merge(plan: plan_status(subscription), ai_conversations: ai.merge(forecast_date: forecast_date(**ai.slice(:used, :limit))))
  end

  # The day the AI conversation limit is reached at the pace of the billing period so far, or nil when it isn't reached before the reset.
  def forecast_date(used:, limit:)
    return if limit.nil? || used.zero? || used >= limit

    started, resets = subscription.quota_period
    per_day = used / [(Time.current - started) / 1.day, 1].max
    date = Time.current + ((limit - used) / per_day).days
    date.to_date.iso8601 if date < resets
  end

  def plan_status(subscription)
    {
      billing_enabled: subscription.enabled?,
      trial: subscription.trial_active?,
      trial_ends_at: (subscription.trial_ends_at&.to_i if subscription.trial_active?),
      ai_replies_paused: !pause_reason.nil?,
      ai_pause_reason: pause_reason,
      quota_resets_at: subscription.quota_period.last.to_i
    }
  end

  def widget_installed?
    return @widget_installed if defined?(@widget_installed)

    widget_inboxes = account.inboxes.where(channel_type: 'Channel::WebWidget')
    @widget_installed = ContactInbox.where(inbox_id: widget_inboxes.select(:id)).where.not(website_activity: {}).exists? ||
                        account.conversations.exists?(inbox_id: widget_inboxes.select(:id))
  end

  def mailbox_connected?
    account.inboxes.exists?(channel_type: 'Channel::Email')
  end

  def domain_status
    portals = account.portals.where.not(custom_domain: [nil, ''])
    return 'none' unless portals.exists?

    portals.any? { |portal| portal.ssl_settings['cf_status'] == 'active' } ? 'verified' : 'pending'
  end
end

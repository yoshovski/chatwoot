# Counts for the Home page cards. Each card links to its own page for detail, so this returns numbers only.
class Captain::HomeSummaryBuilder
  PERFORMANCE_WINDOW = 7.days
  PRODUCT_SOURCE_USED = [{ kind: 'product', used: true }].to_json.freeze

  def initialize(account, user)
    @account = account
    @user = user
  end

  def summary
    {
      setup: setup_steps,
      quick_actions: quick_actions,
      performance: performance,
      project_status: project_status,
      usage: usage
    }
  end

  private

  attr_reader :account, :user

  def setup_steps
    {
      ai_agent: account.captain_assistants.exists?,
      knowledge: account.captain_assistant_responses.approved.exists? || account.captain_documents.exists?,
      agent_inbox: CaptainInbox.joins(:captain_assistant).exists?(captain_assistants: { account_id: account.id }),
      chat_widget: widget_installed?,
      mailbox: mailbox_connected?,
      teammate: account.account_users.count > 1
    }
  end

  def quick_actions
    {
      unassigned_conversations: accessible_conversations.open.unassigned.count,
      unanswered_questions: Captain::KnowledgeGapFinder.new(user, account).perform.open.count,
      live_visitors: OnlineStatusTracker.get_available_contact_ids(account.id).size
    }
  end

  def performance
    {
      ai_resolution_rate: ai_resolution_rate,
      sales_assisted: account.captain_agent_sessions.session_assistant.where(created_at: performance_range)
                             .where('sources @> ?', PRODUCT_SOURCE_USED).distinct.count(:subject_id),
      leads_captured: account.messages.where(id: lead_note_ids, created_at: performance_range).count
    }
  end

  def project_status
    {
      widget_installed: widget_installed?,
      mailbox_connected: mailbox_connected?,
      domain: domain_status
    }
  end

  def usage
    limits = account.captain_monthly_limit
    month = Time.current.beginning_of_month..Time.current
    {
      ai_replies: { used: account.captain_agent_sessions.session_assistant.where(created_at: month).count, limit: finite(limits[:responses]) },
      documents: { used: account.captain_documents.count, limit: finite(limits[:documents]) },
      conversations: { used: account.conversations.where(created_at: month).count, limit: nil }
    }
  end

  # The Overview page's auto-resolution rate, weighted by each agent's handled conversations.
  def ai_resolution_rate
    metrics = account.captain_assistants.map { |assistant| Captain::AssistantStatsBuilder.new(assistant, '7').metrics }
    handled = metrics.sum { |metric| metric[:conversations_handled][:current] }
    return 0 if handled.zero?

    resolved = metrics.sum { |metric| metric[:auto_resolution_rate][:current] * metric[:conversations_handled][:current] }
    (resolved / handled).round(1)
  end

  def lead_note_ids
    account.conversations.where("additional_attributes ->> 'business_lead_captured' = 'true'")
           .select(Arel.sql("(additional_attributes ->> 'business_lead_summary_note_id')::bigint"))
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

  def accessible_conversations
    Conversations::PermissionFilterService.new(account.conversations, user, account).perform
  end

  def performance_range
    PERFORMANCE_WINDOW.ago..Time.current
  end

  def finite(limit)
    limit.to_i >= ChatwootApp.max_limit ? nil : limit.to_i
  end
end

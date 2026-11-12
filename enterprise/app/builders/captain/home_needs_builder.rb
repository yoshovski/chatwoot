# "Needs you" on the Home page: named items the owner can act on with one button, most urgent kind first, plus the
# most recent leads. Every list is capped, so the page stays short and the query count is fixed.
# Agents see the conversations they can open; problems with knowledge, actions and channels are for administrators.
class Captain::HomeNeedsBuilder
  LIMIT = 3
  FAILED_ACTION_WINDOW = 7.days

  def initialize(account, user)
    @account = account
    @user = user
  end

  def needs
    items = handoffs + knowledge_gaps
    items += failed_actions + failed_syncs + channel_problems if administrator?
    items
  end

  def leads
    accessible_conversations.where("conversations.additional_attributes ->> 'business_lead_captured' = 'true'")
                            .includes(:contact).reorder(last_activity_at: :desc).limit(LIMIT)
                            .map do |conversation|
      { id: conversation.display_id, name: conversation.contact&.name, at: conversation.last_activity_at.to_i }
    end
  end

  # Channels that lost their connection. The flag lives in Redis, so this costs no database query per inbox.
  def channel_problems
    @channel_problems ||= account.inboxes.includes(:channel).select { |inbox| inbox.channel.try(:reauthorization_required?) }
                                 .first(LIMIT).map { |inbox| { key: 'channel', id: inbox.id, name: inbox.name } }
  end

  def failed_syncs
    @failed_syncs ||= begin
      documents = account.captain_documents.sync_failed.reorder(last_sync_attempted_at: :desc).limit(LIMIT)
                         .map { |doc| failed_sync(doc.assistant_id, doc.name.presence || doc.external_link, doc.last_sync_attempted_at) }
      sources = Captain::WebsiteSource.where(account_id: account.id, status: 'failed').reorder(updated_at: :desc).limit(LIMIT)
                                      .map { |source| failed_sync(source.assistant_id, source.url, source.updated_at) }
      (documents + sources).first(LIMIT)
    end
  end

  private

  attr_reader :account, :user

  # Conversations that wait for a person: open, nobody assigned, oldest wait first.
  def handoffs
    accessible_conversations.open.unassigned.where.not(waiting_since: nil).includes(:contact, :inbox)
                            .reorder(waiting_since: :asc).limit(LIMIT).map do |conversation|
      { key: 'handoff', id: conversation.display_id, name: conversation.contact&.name, inbox: conversation.inbox.name,
        at: conversation.waiting_since.to_i }
    end
  end

  # The questions the AI agent could not answer, asked most often first.
  def knowledge_gaps
    Captain::KnowledgeGapFinder.new(user, account).perform.open.reorder(occurrences_count: :desc, last_seen_at: :desc).limit(LIMIT)
                               .map do |gap|
      { key: 'gap', id: gap.id, assistant_id: gap.assistant_id, question: gap.question, count: gap.occurrences_count,
        at: gap.last_seen_at.to_i }
    end
  end

  # Follow-ups that failed this week and tool connections that are down.
  def failed_actions
    scheduled = Captain::ScheduledAction.where(account_id: account.id, status: 'failed', updated_at: FAILED_ACTION_WINDOW.ago..)
                                        .includes(:conversation).reorder(updated_at: :desc).limit(LIMIT).map do |action|
      { key: 'failed_action', kind: action.kind, id: action.conversation.display_id, at: action.updated_at.to_i }
    end
    servers = account.captain_mcp_servers.where(status: 'failed').reorder(updated_at: :desc).limit(LIMIT).map do |server|
      { key: 'failed_action', kind: 'connection', id: server.id, name: server.name, at: server.updated_at.to_i }
    end
    (scheduled + servers).first(LIMIT)
  end

  def failed_sync(assistant_id, name, at)
    { key: 'failed_sync', assistant_id: assistant_id, name: name, at: at&.to_i }
  end

  def accessible_conversations
    Conversations::PermissionFilterService.new(account.conversations, user, account).perform
  end

  def administrator?
    account.account_users.find_by(user_id: user.id)&.administrator?
  end
end

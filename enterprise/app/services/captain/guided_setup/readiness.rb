# Whether an AI agent can go live on the website chat. Same idea as Captain::Leads::NotificationReadiness: one status the
# setup screen shows and the go-live endpoint enforces. Pages still importing don't block going live.
class Captain::GuidedSetup::Readiness
  def self.status(assistant)
    return 'no_agent' unless assistant
    return 'ready' if assistant.documents.enabled.available.exists? || assistant.responses.approved.exists?
    return 'importing' if assistant.documents.exists?

    'no_knowledge'
  end

  def self.live_ready?(status) = %w[ready importing].include?(status)
end

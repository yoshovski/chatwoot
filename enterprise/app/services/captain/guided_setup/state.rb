# What the guided setup stepper needs to pick up where the account left off: the first AI agent, its newest website
# source and the website chat inbox.
class Captain::GuidedSetup::State
  def initialize(account)
    @account = account
  end

  def assistant
    @assistant ||= account.captain_assistants.order(:id).first
  end

  def website_source
    assistant&.website_sources&.order(created_at: :desc)&.first
  end

  def widget_inbox
    account.inboxes.where(channel_type: 'Channel::WebWidget').order(:id).first
  end

  def payload
    inbox = widget_inbox
    source = website_source
    status = Captain::GuidedSetup::Readiness.status(assistant)
    {
      assistant_id: assistant&.id,
      website_source: source&.as_json(only: %i[id url status]),
      widget_inbox: inbox && widget_payload(inbox),
      agent_live: inbox.present? && assistant.present? && assistant.captain_inboxes.exists?(inbox_id: inbox.id),
      readiness: status,
      **import_progress(source, status)
    }
  end

  private

  attr_reader :account

  # quick_ready: the instant agent stored its pages and the agent can answer from knowledge.
  # learned/total: quick-start pages until the owner selects pages, then selected pages the full import has stored.
  def import_progress(source, status)
    instant = assistant&.config.to_h['instant_agent'] || {}
    selected = source&.selected_urls.presence
    learned = learned_documents(source, selected).count
    {
      instant_agent: instant.slice('status', 'language', 'brand_color', 'logo_url', 'starter_questions').presence,
      quick_ready: instant['status'] == 'ready' && status == 'ready',
      learned: learned,
      total: selected ? selected.size : learned
    }
  end

  def learned_documents(source, selected)
    return Captain::Document.none unless source

    documents = assistant.documents.enabled.where("metadata->>'website_source_id' = ?", source.id.to_s)
    return documents.where(external_link: selected).where.not(last_synced_at: nil) if selected

    documents.available.where("metadata->>'quick_start' = 'true'")
  end

  def widget_payload(inbox)
    { id: inbox.id, name: inbox.name, website_url: inbox.channel.website_url, web_widget_script: inbox.channel.web_widget_script }
  end
end

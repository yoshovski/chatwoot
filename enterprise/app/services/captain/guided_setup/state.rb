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
      readiness: status
    }
  end

  private

  attr_reader :account

  def widget_payload(inbox)
    { id: inbox.id, name: inbox.name, website_url: inbox.channel.website_url, web_widget_script: inbox.channel.web_widget_script }
  end
end

class WebsiteActivityListener < BaseListener
  def website_activity_updated(event)
    contact_inbox = event.data[:contact_inbox]
    inbox = contact_inbox.inbox
    tokens = (inbox.members.pluck(:pubsub_token) + inbox.account.administrators.pluck(:pubsub_token)).uniq
    payload = { account_id: inbox.account_id, contact_inbox_id: contact_inbox.id }
    ActionCableBroadcastJob.perform_later(tokens, 'website_activity.updated', payload) if tokens.any?
  end
end

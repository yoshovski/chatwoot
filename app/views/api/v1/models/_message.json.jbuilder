json.id message.id
json.content message.content
json.inbox_id message.inbox_id
json.echo_id message.echo_id if message.echo_id
json.conversation_id message.conversation.display_id
json.message_type message.message_type_before_type_cast
json.content_type message.content_type
json.status message.status
json.content_attributes message.content_attributes
json.created_at message.created_at.to_i
json.private message.private
json.source_id message.source_id
json.sender message.sender.push_event_data if message.sender
json.attachments message.attachments.map(&:push_event_data) if message.attachments.present?
# Captain replies record how many sources their searches found, so the dashboard can place the Sources button after a reload too.
# Replies from before captain_sources_found recorded only the cited ones as captain_sources_used.
captain_sources = message.additional_attributes.to_h.slice('captain_sources_found', 'captain_sources_used') if ChatwootApp.enterprise?
json.additional_attributes captain_sources if captain_sources.present?

json.set! :call, message.call.push_event_data if message.content_type == 'voice_call' && message.respond_to?(:call) && message.call.present?

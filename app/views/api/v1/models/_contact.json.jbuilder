json.additional_attributes resource.additional_attributes
json.availability_status resource.availability_status
json.email resource.email
json.id resource.id
json.name resource.name
json.phone_number resource.phone_number
json.blocked resource.blocked
json.identifier resource.identifier
json.company_id resource.company_id if Current.account&.feature_enabled?('companies')
json.thumbnail resource.avatar_url
json.custom_attributes resource.custom_attributes
json.last_activity_at resource.last_activity_at.to_i if resource[:last_activity_at].present?
json.created_at resource.created_at.to_i if resource[:created_at].present?
# we only want to output contact inbox when its /contacts endpoints
if defined?(with_contact_inboxes) && with_contact_inboxes.present?
  json.contact_inboxes do
    json.array! resource.contact_inboxes do |contact_inbox|
      json.partial! 'api/v1/models/contact_inbox', formats: [:json], resource: contact_inbox
    end
  end
end

if @include_directory_details
  json.conversations_count resource[:conversations_count].to_i
  json.labels resource.taggings.select { |tagging| tagging.context == 'labels' }.map { |tagging| tagging.tag.name }.uniq
  json.contact_type resource.contact_type
  activities = resource.contact_inboxes.filter_map { |item| item.website_activity.presence }
  activity = activities.max_by { |item| item.dig('current_page', 'last_seen_at').to_s }
  json.website_activity activity
end

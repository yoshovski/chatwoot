json.account_id resource.account_id
json.config resource.client_config.merge(
  'auto_resolve_mode' => resource.auto_resolve_mode,
  'auto_resolve_after' => resource.inactivity_threshold_minutes,
  'send_inactivity_resolution_message' => resource.send_inactivity_resolution_message?,
  'suggested_replies' => resource.suggested_replies?,
  'max_suggested_replies' => resource.max_suggested_replies,
  'product_cards' => resource.product_cards?,
  'link_allowlist' => resource.link_allowlist,
  'image_allowlist' => resource.image_allowlist
)
json.created_at resource.created_at.to_i
json.detected_business_type resource.detected_business_type
json.description resource.description
json.guardrails resource.guardrails
json.id resource.id
json.name resource.name
json.avatar_url resource.avatar_url.presence || resource.default_avatar_url
json.has_custom_avatar resource.avatar.attached?
json.response_guidelines resource.response_guidelines
json.updated_at resource.updated_at.to_i
json.prompt_presets do
  json.tone Captain::Assistant::TONE_INSTRUCTIONS
  json.answer_length Captain::Assistant::ANSWER_LENGTH_INSTRUCTIONS[resource.answer_format]
end

json.knowledge_sync do
  json.enabled resource.account.feature_enabled?('captain_document_auto_sync')
  json.interval_hours resource.account.captain_document_sync_interval&.in_hours
end

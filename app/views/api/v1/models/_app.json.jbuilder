json.id resource.id
json.name resource.name
json.description resource.description
json.short_description resource.short_description.presence
json.enabled resource.enabled?(@current_account)

if Current.account_user&.administrator?
  json.call(resource.params, *resource.params.keys)
  if resource.id == 'hubspot'
    json.settings_form_schema(resource.params[:settings_form_schema].map do |field|
      field.merge('label' => I18n.t("integration_apps.hubspot.fields.#{field['name']}.label"),
                  'help' => I18n.t("integration_apps.hubspot.fields.#{field['name']}.help"))
    end)
  end
  json.action resource.action
  json.button resource.action
end

json.hooks do
  json.array! @current_account.hooks.where(app_id: resource.id) do |hook|
    json.partial! 'api/v1/models/hook', formats: [:json], resource: hook
  end
end

module Enterprise::Integrations::App
  def active_for_account?(account)
    return GlobalConfigService.load('HUBSPOT_CLIENT_ID', nil).present? if id == 'hubspot'

    super
  end
end

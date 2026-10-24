# The HubSpot contact shown next to a conversation.
class Crm::Hubspot::ContactCardService
  PROPERTIES = %w[firstname lastname email phone lifecyclestage hs_lead_status hubspot_owner_id createdate lastmodifieddate].freeze
  CARD_CACHE_TTL = 2.minutes
  OPTIONS_CACHE_TTL = 1.hour
  OWNERS_SCOPE = 'crm.objects.owners.read'.freeze

  def initialize(hook)
    @hook = hook
    @client = Crm::Hubspot::Client.new(hook)
  end

  def perform(contact)
    Rails.cache.fetch("hubspot/#{@hook.id}/contact_card/#{contact.id}", expires_in: CARD_CACHE_TTL) do
      record = find_record(contact)
      record ? card(record) : { found: false }
    end
  end

  private

  def find_record(contact)
    hubspot_id = contact.additional_attributes.dig('external', 'hubspot_id')
    record = fetch_by_id(hubspot_id) if hubspot_id.present?
    record || (@client.search_contact(contact.email, PROPERTIES) if contact.email.present?)
  end

  def fetch_by_id(hubspot_id)
    @client.contact(hubspot_id, PROPERTIES)
  rescue Crm::Hubspot::Client::NotFoundError
    nil
  end

  def card(record)
    values = record.fetch('properties')
    {
      found: true, id: record['id'], url: record_url(record['id']),
      name: [values['firstname'], values['lastname']].compact_blank.join(' ').presence,
      email: values['email'], phone: values['phone'],
      lifecyclestage: option_label('lifecyclestage', values['lifecyclestage']),
      hs_lead_status: option_label('hs_lead_status', values['hs_lead_status']),
      owner_name: owner_name(values['hubspot_owner_id']),
      createdate: values['createdate'], lastmodifieddate: values['lastmodifieddate']
    }
  end

  # Refresh tokens carry the portal's data center (na1-..., eu1-...); EU portals live on app-eu1.hubspot.com.
  def record_url(id)
    host = @hook.settings['refresh_token'].to_s.start_with?('eu1-') ? 'app-eu1.hubspot.com' : 'app.hubspot.com'
    "https://#{host}/contacts/#{@hook.settings.fetch('portal_id')}/record/0-1/#{id}"
  end

  def option_label(property, value)
    return if value.blank?

    options = Rails.cache.fetch("hubspot/#{@hook.id}/property_options/#{property}", expires_in: OPTIONS_CACHE_TTL) do
      @client.property(property).fetch('options', []).to_h { |option| [option['value'], option['label']] }
    end
    options[value] || value
  end

  def owner_name(owner_id)
    return if owner_id.blank? || Array(@hook.settings['scopes']).exclude?(OWNERS_SCOPE)

    owner = @client.owner(owner_id)
    [owner['firstName'], owner['lastName']].compact_blank.join(' ').presence || owner['email']
  rescue Crm::Hubspot::Client::NotFoundError
    nil
  end
end

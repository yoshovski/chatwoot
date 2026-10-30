class Telnyx::PhoneNumberLookup
  pattr_initialize [:client!]

  def id_for(phone_number)
    response = client.get('/phone_numbers', query: { 'filter[phone_number]' => phone_number })
    Array(response['data']).first&.dig('id')
  end
end

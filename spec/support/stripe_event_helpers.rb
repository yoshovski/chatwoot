module StripeEventHelpers
  def build_stripe_event(type:, object:, id: "evt_#{SecureRandom.hex(6)}", created: Time.current.to_i, previous_attributes: nil)
    data = { object: object }
    data[:previous_attributes] = previous_attributes if previous_attributes
    Stripe::Event.construct_from({ id: id, object: 'event', type: type, created: created, data: data })
  end
end

RSpec.configure { |config| config.include StripeEventHelpers }

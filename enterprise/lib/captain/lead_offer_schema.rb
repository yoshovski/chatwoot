class Captain::LeadOfferSchema < RubyLLM::Schema
  string :offer, description: 'One sentence offering email follow-up from the team, in the visitor language'
  string :lead_type, description: 'Exact name of the configured lead type that fits best'
  string :summary, description: 'One to three sentences summarizing the business inquiry'

  def self.for(lead_types)
    output = new.to_json_schema.deep_dup
    output.fetch(:schema).fetch(:properties).fetch(:lead_type)[:enum] = lead_types
    output
  end
end

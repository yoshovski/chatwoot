# TODO: Wrap the schema lib under ai-agents
# So we can extend it as Agents::Schema
class Captain::ResponseSchema < RubyLLM::Schema
  string :reasoning, description: "Agent's thought process"
  array :response_parts,
        description: 'Ordered parts of the message to send to the user. Keep all customer-visible text within each part text field.',
        min_items: 1 do
    object do
      string :text, description: 'Customer-visible response text without citation markers or source URLs.', min_length: 1
      array :citation_indexes,
            description: 'Numeric citation indexes from FAQ results that support this text. Use an empty array when none apply.' do
        integer minimum: 1
      end
    end
  end

  def self.for(suggested_replies: false, max_suggested_replies: 3)
    return self unless suggested_replies

    limit = (max_suggested_replies || 3).to_i.clamp(1, 5)
    @schema_cache ||= {}
    @schema_cache[limit] ||= build_schema_with_suggestions(limit)
  end

  def self.build_schema_with_suggestions(limit)
    RubyLLM::Schema.create do
      name 'CaptainResponse'
      string :reasoning, description: "Agent's thought process"
      array :response_parts,
            description: 'Ordered parts of the message to send to the user. Keep all customer-visible text within each part text field.',
            min_items: 1 do
        object do
          string :text, description: 'Customer-visible response text without citation markers or source URLs.', min_length: 1
          array :citation_indexes,
                description: 'Numeric citation indexes from FAQ results that support this text. Use an empty array when none apply.' do
            integer minimum: 1
          end
        end
      end
      Captain::ResponseSchema.define_suggested_replies(self, limit)
    end
  end

  def self.define_suggested_replies(builder, limit)
    builder.array :suggested_replies,
                  description: "0 to #{limit} short, specific next actions for the customer, each at most 80 characters. Empty array if none apply.",
                  max_items: limit do
      string max_length: 80
    end
  end
end

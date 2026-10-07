# TODO: Wrap the schema lib under ai-agents
# So we can extend it as Agents::Schema
class Captain::ResponseSchema < RubyLLM::Schema
  # The handoff decision travels with the answer, like the [HANDOFF] marker in a
  # text reply, so a reply that promises a colleague can't skip the handoff.
  HANDOFF_REQUESTED_DESCRIPTION = 'True when this reply hands the conversation to a human colleague now, including whenever it tells ' \
                                  'the customer that a colleague or the team will continue, follow up, or confirm something. ' \
                                  'Also use the handoff tool when it is available, and say in the reply that a colleague will ' \
                                  'continue in this chat. False when no handoff is needed, or when you only ask whether the customer ' \
                                  'wants a human.'.freeze

  array :response_parts,
        description: 'Ordered parts of the message to send to the user. Keep all customer-visible text within each part text field.',
        min_items: 1 do
    object do
      string :text, description: 'Customer-visible response text without citation markers or source URLs.', min_length: 1
      array :citation_indexes,
            description: 'Source indexes of the tool results this text relies on. Use an empty array when none apply.' do
        integer minimum: 1
      end
    end
  end
  boolean :handoff_requested, description: HANDOFF_REQUESTED_DESCRIPTION

  def self.for(suggested_replies: false, max_suggested_replies: 3, product_cards: false)
    return self unless suggested_replies || product_cards

    limit = (max_suggested_replies || 3).to_i.clamp(1, 5)
    cache_key = "#{suggested_replies}:#{limit}:#{product_cards}"
    @schema_cache ||= {}
    @schema_cache[cache_key] ||= build_schema(
      suggested_replies: suggested_replies,
      limit: limit,
      product_cards: product_cards
    )
  end

  def self.build_schema(suggested_replies:, limit:, product_cards:)
    RubyLLM::Schema.create do
      name 'CaptainResponse'
      array :response_parts,
            description: 'Ordered parts of the message to send to the user. Keep all customer-visible text within each part text field.',
            min_items: 1 do
        object do
          string :text, description: 'Customer-visible response text without citation markers or source URLs.', min_length: 1
          array :citation_indexes,
                description: 'Source indexes of the tool results this text relies on. Use an empty array when none apply.' do
            integer minimum: 1
          end
        end
      end
      boolean :handoff_requested, description: Captain::ResponseSchema::HANDOFF_REQUESTED_DESCRIPTION
      Captain::ResponseSchema.define_suggested_replies(self, limit) if suggested_replies
      Captain::ResponseSchema.define_product_handles(self) if product_cards
    end
  end

  def self.build_schema_with_suggestions(limit)
    build_schema(suggested_replies: true, limit: limit, product_cards: false)
  end

  def self.define_suggested_replies(builder, limit)
    builder.array :suggested_replies,
                  description: "0 to #{limit} short, specific next actions for the customer, each at most 80 characters. Empty array if none apply.",
                  max_items: limit do
      string max_length: 80
    end
  end

  def self.define_product_handles(builder)
    builder.array :product_handles,
                  description: 'Up to 5 product handles to display as product cards, ordered best fit first. ' \
                               'Include only products returned by product tools in this turn. Empty array if none apply.',
                  max_items: 5 do
      string
    end
  end
end

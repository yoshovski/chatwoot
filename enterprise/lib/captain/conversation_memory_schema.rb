class Captain::ConversationMemorySchema < RubyLLM::Schema
  string :summary, min_length: 1,
                   description: 'Factual conversation summary, at most 700 estimated tokens. Preserve unresolved questions and corrections.'
  array :facts, max_items: 20 do
    object do
      string :category, enum: %w[product requirement preference decision unresolved]
      string :value, max_length: 200, description: 'Exact identifiers, quantities, constraints and negations; distinguish claims from verified facts.'
      array :source_message_ids, min_items: 1 do
        integer minimum: 1
      end
    end
  end
end

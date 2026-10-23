# Constrains both per-batch summaries and the merged profile to the same editable limits.
class Captain::Knowledge::BriefSchema < RubyLLM::Schema
  object :overview do
    string :text, min_length: 1, max_length: Captain::Knowledge::BriefGenerator::OVERVIEW_LENGTH
    array :document_ids, min_items: 1 do
      integer minimum: 1
    end
  end
  array :topics, max_items: Captain::Knowledge::BriefGenerator::MAX_TOPICS do
    object do
      string :title, min_length: 1, max_length: 100
      string :summary, min_length: 1, max_length: Captain::Knowledge::BriefGenerator::TOPIC_LENGTH
      array :document_ids, min_items: 1 do
        integer minimum: 1
      end
    end
  end
  string :business_type, enum: Captain::Assistant::BUSINESS_TYPES

  def self.for(ids)
    output = new.to_json_schema.deep_dup
    properties = output.fetch(:schema).fetch(:properties)
    properties.fetch(:overview).fetch(:properties).fetch(:document_ids).fetch(:items)[:enum] = ids
    properties.fetch(:topics).fetch(:items).fetch(:properties).fetch(:document_ids).fetch(:items)[:enum] = ids
    output
  end
end

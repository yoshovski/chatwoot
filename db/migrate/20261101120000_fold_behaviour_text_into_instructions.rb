# Agent behaviour is fixed now (Captain::Behaviour). A custom role or fixed welcome the merchant wrote becomes an
# instruction, so their text keeps applying; the old values are kept under legacy_behaviour for `down`.
class FoldBehaviourTextIntoInstructions < ActiveRecord::Migration[7.1]
  class Assistant < ApplicationRecord # rubocop:disable Style/OneClassPerFile
    self.table_name = 'captain_assistants'
  end

  LEGACY_KEY = 'legacy_behaviour'.freeze
  BEHAVIOUR_KEYS = %w[agent_role agent_role_prompt visitor_audience greeting_mode welcome_message separate_follow_up].freeze
  CONTACT_PLACEHOLDER = /\{\{\s*contact\.(\w+)\s*\}\}/

  def up
    Assistant.find_each do |assistant|
      next if assistant.config.key?(LEGACY_KEY)

      guidelines = folded_guidelines(assistant.config)
      next if guidelines.empty?

      assistant.update_columns( # rubocop:disable Rails/SkipsModelValidations
        response_guidelines: Array(assistant.response_guidelines) + guidelines,
        config: assistant.config.merge(LEGACY_KEY => assistant.config.slice(*BEHAVIOUR_KEYS))
      )
    end
  end

  def down
    Assistant.where("config->'#{LEGACY_KEY}' IS NOT NULL").find_each do |assistant|
      legacy = assistant.config[LEGACY_KEY]
      assistant.update_columns( # rubocop:disable Rails/SkipsModelValidations
        response_guidelines: Array(assistant.response_guidelines) - folded_guidelines(legacy),
        config: assistant.config.except(LEGACY_KEY).merge(legacy)
      )
    end
  end

  private

  # Only text that was in use: the role prompt applied with the custom role, the welcome with the fixed greeting.
  def folded_guidelines(config)
    role = config['agent_role_prompt'].to_s.strip
    welcome = config['welcome_message'].to_s.strip.gsub(CONTACT_PLACEHOLDER) { "[the customer's #{Regexp.last_match(1).tr('_', ' ')}]" }
    [
      ("Role: #{role}" if config['agent_role'] == 'custom' && role.present?),
      ("Use this welcome on the first reply: #{welcome}" if config['greeting_mode'] == 'fixed' && welcome.present?)
    ].compact
  end
end

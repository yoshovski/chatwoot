# Custom tools become actions: ordered steps, saved response outputs, background or confirm, and encrypted auth.
# Existing tools get one request step built from the legacy columns, which stay (and keep being written) for one
# release so an rc can still roll back. Auth secrets move from auth_config into the encrypted column.
class AddActionStepsToCaptainCustomTools < ActiveRecord::Migration[7.1]
  SECRET_AUTH_KEYS = %w[token password key].freeze

  class MigrationCustomTool < ApplicationRecord # rubocop:disable Style/OneClassPerFile
    self.table_name = 'captain_custom_tools'
    encrypts :encrypted_auth if Chatwoot.encryption_configured?
  end

  def up
    change_table :captain_custom_tools, bulk: true do |t|
      t.jsonb :steps, null: false, default: []
      t.jsonb :outputs, null: false, default: []
      t.string :execution_mode, null: false, default: 'background'
      t.jsonb :messages, null: false, default: {}
      t.text :encrypted_auth
    end

    MigrationCustomTool.reset_column_information
    MigrationCustomTool.find_each { |tool| migrate_tool(tool) }
  end

  def down
    MigrationCustomTool.find_each { |tool| restore_auth(tool) }

    change_table :captain_custom_tools, bulk: true do |t|
      t.remove :steps, :outputs, :execution_mode, :messages, :encrypted_auth
    end
  end

  private

  def migrate_tool(tool)
    auth_config = tool.auth_config.to_h
    secrets = auth_config.slice(*SECRET_AUTH_KEYS).compact_blank
    tool.update_columns( # rubocop:disable Rails/SkipsModelValidations
      steps: [legacy_request_step(tool)],
      encrypted_auth: secrets.present? ? secrets.to_json : nil,
      auth_config: auth_config.except(*SECRET_AUTH_KEYS)
    )
  end

  def legacy_request_step(tool)
    { 'key' => 'request', 'type' => 'request', 'method' => tool.http_method, 'url' => tool.endpoint_url,
      'headers' => [], 'body_type' => 'json', 'body' => tool.request_template.to_s }
  end

  def restore_auth(tool)
    return if tool.encrypted_auth.blank?

    tool.update_columns(auth_config: tool.auth_config.to_h.merge(JSON.parse(tool.encrypted_auth))) # rubocop:disable Rails/SkipsModelValidations
  end
end

class WidenIntegrationHookAccessTokens < ActiveRecord::Migration[7.2]
  def up
    # ApplicationRecord limits strings to 255 characters; OAuth tokens can be longer.
    # Text storage retains encryption and uses the existing bounded text validation.
    change_column :integrations_hooks, :access_token, :text
  end

  def down
    change_column :integrations_hooks, :access_token, :string
  end
end

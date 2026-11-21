class AddLocalizedReplyCopyToCaptainScenarios < ActiveRecord::Migration[7.2]
  def change
    add_column :captain_scenarios, :localized_reply_copy, :jsonb, default: {}, null: false
  end
end

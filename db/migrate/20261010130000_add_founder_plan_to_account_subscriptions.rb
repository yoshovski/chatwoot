class AddFounderPlanToAccountSubscriptions < ActiveRecord::Migration[7.2]
  def change
    add_column :account_subscriptions, :founder_plan, :boolean, default: false, null: false
  end
end

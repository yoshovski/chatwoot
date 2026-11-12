# The plan a public signup starts its trial on, the plan an unpaid trial ends on, and a monthly limit on all
# conversations (the Free plan). The plans themselves are seed data: rake billing_plans:seed.
class AddSignupFieldsToBillingPlans < ActiveRecord::Migration[7.2]
  def change
    add_column :billing_plans, :signup_default, :boolean, default: false, null: false
    add_column :billing_plans, :conversations_limit, :integer
    add_reference :billing_plans, :after_trial_plan, foreign_key: { to_table: :billing_plans, on_delete: :nullify }
    add_index :billing_plans, :signup_default, unique: true, where: 'signup_default'
  end
end

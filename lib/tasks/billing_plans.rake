# The plans the site sells. Safe to run twice: a plan that already exists (by name) keeps what Super Admin set, and
# the signup and after-trial links are only filled in where they are empty.
namespace :billing_plans do
  desc 'Create the Free, Starter, Growth and Pro plans and make Growth the signup trial that ends on Free'
  task seed: :environment do
    ai_features = %w[captain_integration captain_integration_v2 native_ai_knowledge shopify_integration crm_integration]
    base_features = %w[help_center campaigns reports]
    plans = {
      'Free' => { position: 0, monthly_price_cents: 0, ai_conversations_limit: 0, conversations_limit: 100, features: base_features },
      'Starter' => { position: 1, monthly_price_cents: 1900, ai_conversations_limit: 50, features: base_features + ai_features },
      'Growth' => { position: 2, monthly_price_cents: 3900, ai_conversations_limit: 150, trial_ai_conversations_limit: 50, trial_days: 14,
                    features: base_features + ai_features },
      'Pro' => { position: 3, monthly_price_cents: 7900, ai_conversations_limit: 400, features: base_features + ai_features + %w[disable_branding] }
    }.to_h do |name, attributes|
      [name, BillingPlan.create_with(attributes.merge(currency: 'eur')).find_or_create_by!(name: name)]
    end

    growth = plans['Growth']
    growth.update!(after_trial_plan: plans['Free']) if growth.after_trial_plan_id.nil?
    growth.update!(signup_default: true) unless BillingPlan.exists?(signup_default: true)

    plans.each_value { |plan| puts "#{plan.name}: #{plan.monthly_price} #{plan.currency}, #{plan.account_subscriptions.count} accounts" }
    puts "Signup trial: #{BillingPlan.for_signup&.name || 'none'}"
  end
end

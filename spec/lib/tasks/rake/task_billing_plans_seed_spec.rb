require 'rake'
require 'rails_helper'

RSpec.describe Rake::Task do
  subject(:task) { described_class['billing_plans:seed'] }

  before do
    task.reenable
  end

  it 'creates the four plans with Growth as the signup trial that ends on Free' do
    expect { task.invoke }.to output.to_stdout

    plans = BillingPlan.ordered.index_by(&:name)
    expect(plans.keys).to eq(%w[Free Starter Growth Pro])
    expect(plans.values.map(&:monthly_price_cents)).to eq([0, 1900, 3900, 7900])
    expect(plans.values.map(&:ai_conversations_limit)).to eq([0, 50, 150, 400])
    expect(plans['Free'].conversations_limit).to eq(100)
    expect(plans['Growth']).to have_attributes(signup_default: true, after_trial_plan: plans['Free'], trial_days: 14,
                                               trial_ai_conversations_limit: 50)
  end

  it 'is safe to run twice and keeps what Super Admin changed' do
    expect { task.invoke }.to output.to_stdout
    BillingPlan.find_by!(name: 'Starter').update!(monthly_price_cents: 2500)
    task.reenable

    expect { task.invoke }.to output.to_stdout

    expect(BillingPlan.count).to eq(4)
    expect(BillingPlan.find_by!(name: 'Starter').monthly_price_cents).to eq(2500)
  end

  it 'keeps another plan as the signup default' do
    create(:billing_plan, name: 'Custom', signup_default: true)

    expect { task.invoke }.to output.to_stdout

    expect(BillingPlan.for_signup.name).to eq('Custom')
  end
end

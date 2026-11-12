require 'rails_helper'

# T07: an AI reply that leaves 5 or fewer AI conversations asks for an automatic pack.
RSpec.describe ConversationUsageWindow do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent_bot) { create(:agent_bot) }
  let(:plan) { create(:billing_plan, ai_conversations_limit: 6) }
  let(:subscription) { account.subscription_settings }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  before do
    create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)
    account.update!(subscription_settings: { billing_plan_id: plan.id })
    subscription.update!(payment_status: 'active', stripe_subscription_id: 'sub_test')
  end

  def ai_reply
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, sender: agent_bot)
  end

  describe 'auto top-up' do
    before { subscription.update!(enabled: true, stripe_customer_id: 'cus_test', auto_top_up_enabled: true) }

    it 'asks for a pack once an AI reply leaves 5 or fewer AI conversations' do
      expect { ai_reply }.to have_enqueued_job(Enterprise::Billing::AutoTopUpJob).with(account.id)
    end

    it 'asks for nothing while auto top-up is off' do
      subscription.update!(auto_top_up_enabled: false)

      expect { ai_reply }.not_to have_enqueued_job(Enterprise::Billing::AutoTopUpJob)
    end
  end
end

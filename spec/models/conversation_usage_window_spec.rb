require 'rails_helper'

# T03: one AI conversation opens when the AI agent actually replies. Allowance first, then the extra balance.
RSpec.describe ConversationUsageWindow do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent_bot) { create(:agent_bot) }
  let(:plan) { create(:billing_plan, ai_conversations_limit: 1) }
  let(:subscription) { account.subscription_settings }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  before do
    create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)
    account.update!(subscription_settings: { billing_plan_id: plan.id })
    subscription.update!(payment_status: 'active', stripe_subscription_id: 'sub_test')
  end

  def ai_reply(in_conversation = conversation)
    create(:message, account: account, inbox: inbox, conversation: in_conversation, message_type: :outgoing, sender: agent_bot)
  end

  def customer_message(in_conversation = conversation)
    create(:message, account: account, inbox: inbox, conversation: in_conversation, message_type: :incoming)
  end

  describe 'when a window opens' do
    it 'opens one window when the AI agent replies, not for the customer message' do
      customer_message
      expect(account.conversation_usage_windows.count).to eq(0)

      ai_reply
      ai_reply
      expect(account.conversation_usage_windows.count).to eq(1)
      expect(subscription.consumed).to eq(1)
    end

    it 'counts 0 for a conversation only a person answers' do
      customer_message
      create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, sender: create(:user, account: account))

      expect(account.conversation_usage_windows.count).to eq(0)
    end

    it 'counts 0 for a private note by the AI agent' do
      create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, sender: agent_bot, private: true)

      expect(account.conversation_usage_windows.count).to eq(0)
    end

    it 'counts 0 for a conversation blocked at the limit' do
      ai_reply
      blocked = create(:conversation, account: account, inbox: inbox)
      customer_message(blocked)

      expect { ai_reply(blocked) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(account.conversation_usage_windows.where(conversation: blocked)).to be_empty
      expect(subscription.consumed).to eq(1)
    end
  end

  describe 'allowance, then the extra balance' do
    it 'uses the allowance before the extra balance' do
      ExtraAiConversationEntry.credit!(account: account, amount: 2, stripe_reference: 'pi_1')

      first = ai_reply
      expect(first.conversation_usage_windows.last).not_to be_extra
      expect(subscription.extra_ai_conversations).to eq(2)

      second = ai_reply(create(:conversation, account: account, inbox: inbox))
      window = second.conversation_usage_windows.last
      expect(window).to be_extra
      expect(subscription.extra_ai_conversations).to eq(1)
      expect(subscription.consumed).to eq(1)
      expect(window.extra_ai_conversation_entry).to have_attributes(reason: 'usage', amount: -1)
    end

    it 'lets an extra conversation keep replying for its 24 hours, then stops at an empty balance' do
      ExtraAiConversationEntry.credit!(account: account, amount: 1, stripe_reference: 'pi_1')
      ai_reply
      extra_conversation = create(:conversation, account: account, inbox: inbox)
      ai_reply(extra_conversation)

      expect(subscription.extra_ai_conversations).to eq(0)
      expect(account.ai_reply_allowed?(extra_conversation)).to be(true)
      expect { ai_reply(extra_conversation) }.not_to raise_error
      expect(subscription.ai_pause_reason).to eq('limit_reached')
    end

    it 'does not take from the balance for a manual account without a limit' do
      subscription.update!(payment_status: 'manual', manual_ai_access: true, stripe_subscription_id: nil)
      ExtraAiConversationEntry.credit!(account: account, amount: 1, stripe_reference: 'pi_1')

      ai_reply
      ai_reply(create(:conversation, account: account, inbox: inbox))

      expect(account.conversation_usage_windows.where(extra: true)).to be_empty
      expect(subscription.extra_ai_conversations).to eq(1)
    end
  end
end

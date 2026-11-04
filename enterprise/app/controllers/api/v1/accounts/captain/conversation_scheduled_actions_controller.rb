# The AI agent's pending follow-ups in one conversation, for the chip in the conversation's Captain panel.
class Api::V1::Accounts::Captain::ConversationScheduledActionsController < Api::V1::Accounts::BaseController
  before_action :fetch_conversation

  def index
    @scheduled_actions = @conversation.captain_scheduled_actions.pending.order(:due_at)
  end

  def destroy
    action = @conversation.captain_scheduled_actions.pending.find(params[:id])
    action.update!(status: :cancelled, cancelled_at: Time.current, cancel_reason: 'agent')
    head :no_content
  end

  private

  def fetch_conversation
    @conversation = Current.account.conversations.find_by!(display_id: params[:conversation_id])
    authorize @conversation, :show?
  end
end

class Api::V1::Accounts::Captain::ConversationTakeoversController < Api::V1::Accounts::BaseController
  def create
    conversation = Current.account.conversations.find_by!(display_id: params[:conversation_id])
    authorize conversation, :show?

    Captain::Conversation::OwnershipService.new(conversation: conversation).take_over!(Current.user)
    head :ok
  end
end

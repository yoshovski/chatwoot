class Captain::KnowledgeGapFinder
  def initialize(current_user, current_account)
    @current_user = current_user
    @current_account = current_account
  end

  def perform
    gaps = @current_account.captain_knowledge_gaps
    return gaps if account_user&.administrator?

    accessible_gap_ids = Captain::KnowledgeGapOccurrence
                         .where(conversation_id: accessible_conversations.select(:id))
                         .select(:knowledge_gap_id)
    gaps.where(id: accessible_gap_ids)
  end

  private

  def accessible_conversations
    Conversations::PermissionFilterService.new(@current_account.conversations, @current_user, @current_account).perform
  end

  def account_user
    @account_user ||= @current_account.account_users.find_by(user_id: @current_user.id)
  end
end

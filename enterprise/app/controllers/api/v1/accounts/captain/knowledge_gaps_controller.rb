class Api::V1::Accounts::Captain::KnowledgeGapsController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action -> { check_authorization(Captain::KnowledgeGap) }
  before_action :set_accessible_gaps
  before_action :set_gap, except: [:index]

  RESULTS_PER_PAGE = 25
  OCCURRENCE_PREVIEW_LIMIT = 20

  def index
    @current_page = permitted_params[:page] || 1
    filtered_query = apply_filters(@gaps)
    @gaps_count = filtered_query.count
    @gaps = filtered_query.page(@current_page).per(RESULTS_PER_PAGE).to_a
    @reason_counts = Captain::KnowledgeGapOccurrence.where(knowledge_gap_id: @gaps.map(&:id)).group(:knowledge_gap_id, :reason).count
  end

  def show
    @occurrences = @gap.occurrences
                       .where(conversation_id: accessible_conversations.select(:id))
                       .includes(:conversation)
                       .order(created_at: :desc)
                       .limit(OCCURRENCE_PREVIEW_LIMIT)
  end

  def answer
    @gap.with_lock do
      raise ActiveRecord::RecordNotFound unless @gap.open?

      @response = @gap.assistant.responses.create!(answer_params.merge(status: :approved))
      @gap.update!(status: :answered, response: @response)
    end
  end

  def dismiss
    @gap.with_lock do
      raise ActiveRecord::RecordNotFound unless @gap.open?

      @gap.dismissed!
    end
  end

  private

  def apply_filters(base_query)
    base_query = base_query.where(assistant_id: permitted_params[:assistant_id]) if permitted_params[:assistant_id].present?
    base_query = base_query.where(status: permitted_params[:status].presence || :open)
    base_query = base_query.where('question ILIKE ?', "%#{permitted_params[:search]}%") if permitted_params[:search].present?
    base_query
  end

  def set_accessible_gaps
    @gaps = Captain::KnowledgeGapFinder.new(Current.user, Current.account).perform.includes(:assistant).ordered
  end

  def set_gap
    @gap = @gaps.find(permitted_params[:id])
  end

  def accessible_conversations
    Conversations::PermissionFilterService.new(Current.account.conversations, Current.user, Current.account).perform
  end

  def permitted_params
    params.permit(:id, :assistant_id, :page, :status, :search)
  end

  def answer_params
    params.require(:knowledge_gap).permit(:question, :answer)
  end
end

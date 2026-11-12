class Api::V1::Accounts::Captain::KnowledgeGapsController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action -> { check_authorization(Captain::KnowledgeGap) }
  before_action :set_accessible_gaps
  before_action :set_gap, only: [:show, :answer, :dismiss]
  before_action :validate_view, only: [:index]

  RESULTS_PER_PAGE = 25
  OCCURRENCE_PREVIEW_LIMIT = 20
  EXAMPLE_LIMIT = 3
  TOPIC_GAP_LIMIT = 200
  BULK_LIMIT = 100
  # unanswered: open knowledge questions with enough evidence (KnowledgeGap.unanswered). The others list knowledge
  # questions in that status.
  VIEWS = %w[unanswered answered dismissed].freeze

  def index
    @current_page = permitted_params[:page] || 1
    filtered_query = apply_filters(view_scope)
    @gaps_count = filtered_query.count
    @gaps = filtered_query.page(@current_page).per(RESULTS_PER_PAGE).to_a
    @reason_counts = Captain::KnowledgeGapOccurrence.where(knowledge_gap_id: @gaps.map(&:id)).group(:knowledge_gap_id, :reason).count
    @examples = examples_for(@gaps.map(&:id))
  end

  # The Unanswered list grouped by topic, the topic with most conversations first.
  def topics
    gaps = apply_filters(@gaps.unanswered).limit(TOPIC_GAP_LIMIT).to_a
    @examples = examples_for(gaps.map(&:id))
    @topics = gaps.group_by(&:topic).map { |topic, topic_gaps| { topic: topic, gaps: topic_gaps } }
                  .sort_by { |group| -group[:gaps].sum(&:occurrences_count) }
  end

  # What customers asked the AI to do, counted per intent.
  def action_requests
    gaps = apply_filters(@gaps.open.action_request).to_a
    examples = examples_for(gaps.map(&:id))
    @action_requests = gaps.group_by(&:intent).map do |intent, intent_gaps|
      { intent: intent, gaps: intent_gaps, examples: intent_gaps.flat_map { |gap| examples.fetch(gap.id, []) }.uniq.first(EXAMPLE_LIMIT) }
    end
    @action_requests.sort_by! { |request| -request[:gaps].sum(&:occurrences_count) }
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

  def bulk_dismiss
    ids = params.require(:ids)
    return render_could_not_create_error("ids must be a list of at most #{BULK_LIMIT}") unless ids.is_a?(Array) && ids.size <= BULK_LIMIT

    @dismissed_count = @gaps.open.where(id: ids).update_all(status: Captain::KnowledgeGap.statuses[:dismissed], updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  private

  def validate_view
    return if permitted_params[:view].blank? || VIEWS.include?(permitted_params[:view])

    render_could_not_create_error("view must be one of #{VIEWS.join(', ')}")
  end

  def view_scope
    view = permitted_params[:view].presence || 'unanswered'
    view == 'unanswered' ? @gaps.unanswered : @gaps.knowledge.where(status: view)
  end

  def apply_filters(base_query)
    base_query = base_query.where(assistant_id: permitted_params[:assistant_id]) if permitted_params[:assistant_id].present?
    base_query = base_query.where(topic: permitted_params[:topic]) if permitted_params[:topic].present?
    base_query = base_query.where('question ILIKE ?', "%#{permitted_params[:search]}%") if permitted_params[:search].present?
    base_query
  end

  # Up to three distinct raw customer messages per gap, newest first, from conversations the user can see.
  def examples_for(gap_ids)
    Captain::KnowledgeGapOccurrence.where(knowledge_gap_id: gap_ids, conversation_id: accessible_conversations.select(:id))
                                   .where.not(question: nil).order(created_at: :desc).pluck(:knowledge_gap_id, :question)
                                   .group_by(&:first).transform_values { |rows| rows.map(&:last).uniq.first(EXAMPLE_LIMIT) }
  end

  def set_accessible_gaps
    @gaps = Captain::KnowledgeGapFinder.new(Current.user, Current.account).perform.includes(:assistant).ordered
  end

  def set_gap
    @gap = @gaps.find(permitted_params[:id])
  end

  def accessible_conversations
    @accessible_conversations ||= Conversations::PermissionFilterService.new(Current.account.conversations, Current.user, Current.account).perform
  end

  def permitted_params
    params.permit(:id, :assistant_id, :page, :view, :topic, :search)
  end

  def answer_params
    params.require(:knowledge_gap).permit(:question, :answer)
  end
end

class Api::V1::Accounts::Captain::DocumentsController < Api::V1::Accounts::BaseController
  before_action -> { check_authorization(Captain::Assistant) }

  before_action :set_current_page, only: [:index]
  before_action :set_documents, except: [:create]
  before_action :set_document, only: [:show, :update, :destroy, :sync, :drilldown, :generate_faqs]
  before_action :set_assistant, only: [:create]
  RESULTS_PER_PAGE = 25

  def index
    documents = filtered_documents
    @documents_count = documents.count
    @sync_interval_hours = current_sync_interval&.in_hours&.to_i
    @documents = apply_sort(documents, permitted_params[:sort])
    @documents = with_responses_count(@documents).page(@current_page).per(RESULTS_PER_PAGE)
    return unless can_view_drilldown?

    @document_usage_counts = Captain::ConversationUsageBuilder.conversation_counts(@documents, usage_column: :document_ids)
  end

  def show; end

  def create
    return render_could_not_create_error('Missing Assistant') if @assistant.nil?

    @document = @assistant.documents.build(document_params)
    @document.save!
  rescue Captain::Document::LimitExceededError => e
    render_could_not_create_error(e.message)
  rescue ActiveRecord::RecordInvalid => e
    render_could_not_create_error(e.record.errors.full_messages.join(', '))
  end

  # Only who may see the document can change; its source and content come from the sync.
  def update
    @document.update!(params.require(:document).permit(:agents_only, :enabled))
    render :show
  end

  def sync
    case Captain::Documents::SyncRequest.new(@document).perform
    when :unsupported then render_could_not_create_error(I18n.t('captain.documents.sync_not_supported_for_file'))
    when :not_ready then render_could_not_create_error(I18n.t('captain.documents.sync_only_available_documents'))
    else head :accepted
    end
  end

  def generate_faqs
    if @document.pdf_document? && Current.account.dify_knowledge_enabled?
      return render json: { error: 'PDF FAQ generation is not supported in Dify mode' }, status: :unprocessable_entity
    end

    Captain::Documents::ResponseBuilderJob.perform_later(@document, force_ai: true)
    head :accepted
  end

  def drilldown
    render json: Captain::ConversationUsageBuilder.new(@document, drilldown_params, usage_column: :document_ids).build
  end

  def destroy
    @document.destroy
    head :no_content
  end

  private

  def set_documents
    @documents = Current.account.captain_documents.with_attached_pdf_file.with_attached_markdown_file.includes(:assistant, :account)
  end

  def filtered_documents
    Captain::Documents::ListFilter.new(Current.account, permitted_params).apply(@documents)
  end

  def with_responses_count(scope)
    scope.left_joins(:responses)
         .select('captain_documents.*, COUNT(captain_assistant_responses.id) AS responses_count')
         .group('captain_documents.id')
  end

  def set_document
    @document = @documents.find(permitted_params[:id])
  end

  def set_assistant
    @assistant = Current.account.captain_assistants.find_by(id: document_params[:assistant_id])
  end

  def set_current_page
    @current_page = permitted_params[:page] || 1
  end

  def permitted_params
    params.permit(:assistant_id, :page, :id, :account_id, :filter, :source, :sort, :search_key, :section, :website)
  end

  def drilldown_params
    params.permit(:page, :per_page)
  end

  def can_view_drilldown?
    policy(Captain::Assistant).drilldown?
  end

  def apply_sort(scope, sort)
    case sort
    when 'recently_created' then scope.order(created_at: :desc)
    when 'most_used'
      authorize(Captain::Assistant, :drilldown?)
      Captain::ConversationUsageBuilder.order_documents_by_conversation_count(
        scope,
        account_id: Current.account.id,
        assistant_id: permitted_params[:assistant_id]
      )
    else scope.order(updated_at: :desc)
    end
  end

  def current_sync_interval
    return @current_sync_interval if defined?(@current_sync_interval)

    @current_sync_interval = Current.account.captain_document_sync_interval
  end

  def document_params
    params.require(:document).permit(:name, :external_link, :assistant_id, :pdf_file, :markdown_content, :include_linked_pages, :agents_only)
  end
end

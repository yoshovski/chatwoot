class Api::V1::Accounts::Captain::BulkActionsController < Api::V1::Accounts::BaseController
  before_action -> { check_authorization(Captain::Assistant) }
  before_action :validate_params

  ACTIONS = {
    'AssistantResponse' => %w[delete enable disable],
    'AssistantDocument' => %w[delete sync enable disable]
  }.freeze

  def create
    case permitted_params.dig(:fields, :status)
    when 'delete' then delete_records
    when 'sync' then sync_documents
    else update_enabled(permitted_params.dig(:fields, :status) == 'enable')
    end
  end

  private

  # Either explicit ids, or select_all with the list's filters ("all matching" in the UI).
  def validate_params
    status = permitted_params.dig(:fields, :status)
    targeted = permitted_params[:ids].present? || (permitted_params[:select_all] == true && permitted_params[:filters].present?)
    return if targeted && ACTIONS.fetch(permitted_params[:type], []).include?(status)

    render json: { success: false }, status: :unprocessable_content
  end

  def records
    @records ||= begin
      documents = permitted_params[:type] == 'AssistantDocument'
      scope = documents ? Current.account.captain_documents : Current.account.captain_assistant_responses
      if permitted_params[:select_all]
        filter = documents ? Captain::Documents::ListFilter.new(Current.account, filters) : Captain::Faqs::ListFilter.new(filters)
        filter.apply(scope)
      else
        scope.where(id: permitted_params[:ids])
      end
    end
  end

  def filters
    permitted_params[:filters].to_h
  end

  def delete_records
    render json: { count: records.destroy_all.size }
  end

  # Records are updated one by one so their commit callbacks (search index, business profile) still run.
  def update_enabled(enabled)
    count = 0
    records.where.not(enabled: enabled).find_each(batch_size: 100) do |record|
      record.update!(enabled: enabled)
      count += 1
    end
    render json: { count: count }
  end

  def sync_documents
    synced_document_ids = []

    records.find_each(batch_size: 100) do |document|
      next unless document.syncable?
      next unless document.available?

      document.update!(
        sync_status: :syncing,
        sync_step: nil,
        last_sync_error_code: nil,
        last_sync_attempted_at: Time.current
      )
      Captain::Documents::PerformSyncJob.perform_later(document)
      synced_document_ids << document.id
    end

    render json: { ids: synced_document_ids, count: synced_document_ids.size }
  end

  def permitted_params
    params.permit(:type, :select_all, ids: [], fields: [:status],
                                      filters: Captain::Documents::ListFilter::KEYS + Captain::Faqs::ListFilter::KEYS)
  end
end

# Filters an account's documents the way the Data sources list does, so a bulk
# action on "all matching sources" touches exactly the rows the list counts.
class Captain::Documents::ListFilter
  KEYS = %i[assistant_id filter source search_key section website].freeze

  def initialize(account, params)
    @account = account
    @params = params.to_h.symbolize_keys.slice(*KEYS)
  end

  def apply(scope)
    scope = scope.where(assistant_id: @params[:assistant_id]) if @params[:assistant_id].present?
    scope = scope.merge(sections.website_documents(@params[:website])) if sections && @params[:website].present?
    scope = scope.merge(sections.documents([@params[:section]])) if sections && @params[:section].present?
    scope = apply_source(scope)
    scope = apply_status(scope)
    apply_search(scope)
  end

  private

  def sections
    return if @params[:assistant_id].blank?

    @sections ||= Captain::Documents::Sections.new(@account.captain_assistants.find(@params[:assistant_id]))
  end

  def apply_source(scope)
    case @params[:source]
    when 'web' then scope.syncable
    when 'pdf' then scope.pdf_documents
    when 'text' then scope.where("external_link LIKE 'MARKDOWN:%'")
    else scope
    end
  end

  def apply_status(scope)
    case @params[:filter]
    when 'stale' then stale(scope.syncable)
    when 'synced' then up_to_date(scope.syncable)
    when 'syncing' then scope.syncable.sync_in_progress
    when 'failed' then scope.syncable.sync_failed
    when 'enabled' then scope.where(enabled: true)
    when 'disabled' then scope.where(enabled: false)
    else scope
    end
  end

  def apply_search(scope)
    return scope if @params[:search_key].blank?

    query = "%#{ActiveRecord::Base.sanitize_sql_like(@params[:search_key])}%"
    scope.where('captain_documents.name ILIKE :query OR captain_documents.external_link ILIKE :query', query: query)
  end

  def stale(scope)
    return scope.none unless sync_interval

    scope.sync_synced.where(Captain::Document.arel_table[:last_synced_at].lt(sync_interval.ago))
  end

  def up_to_date(scope)
    documents = scope.sync_synced
    return documents unless sync_interval

    documents.where(Captain::Document.arel_table[:last_synced_at].gteq(sync_interval.ago))
  end

  def sync_interval
    return @sync_interval if defined?(@sync_interval)

    @sync_interval = @account.captain_document_sync_interval
  end
end

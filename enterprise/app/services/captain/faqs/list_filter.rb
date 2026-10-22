# Filters an account's FAQs the way the FAQs list does, so a bulk action on
# "all matching FAQs" touches exactly the rows the list counts.
class Captain::Faqs::ListFilter
  KEYS = %i[assistant_id document_id origin search].freeze
  ORIGINS = %w[hand conversation page file].freeze

  def initialize(params)
    @params = params.to_h.symbolize_keys.slice(*KEYS)
  end

  def apply(scope)
    scope = scope.where(assistant_id: @params[:assistant_id]) if @params[:assistant_id].present?
    scope = scope.where(documentable_type: 'Captain::Document', documentable_id: @params[:document_id]) if @params[:document_id].present?
    scope = apply_origin(scope)
    return scope if @params[:search].blank?

    scope.where('question ILIKE :search OR answer ILIKE :search', search: "%#{ActiveRecord::Base.sanitize_sql_like(@params[:search])}%")
  end

  private

  def apply_origin(scope)
    case @params[:origin]
    when 'hand' then scope.where(documentable_type: 'User')
    when 'conversation' then scope.where(documentable_type: 'Conversation')
    when 'page' then from_documents(scope, Captain::Document.syncable)
    when 'file' then from_documents(scope, Captain::Document.where.not(id: Captain::Document.syncable.select(:id)))
    else scope
    end
  end

  def from_documents(scope, documents)
    scope.where(documentable_type: 'Captain::Document', documentable_id: documents.select(:id))
  end
end

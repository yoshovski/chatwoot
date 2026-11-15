class Api::V1::Accounts::CustomFiltersController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_custom_filters, only: [:index]
  before_action :fetch_custom_filter, only: [:show, :update, :destroy]
  before_action :validate_contact_query, only: [:create, :update]
  DEFAULT_FILTER_TYPE = 'conversation'.freeze

  def index; end

  def show; end

  def create
    @custom_filter = Current.account.custom_filters.create!(
      permitted_payload.merge(user: Current.user)
    )
    render json: { error: @custom_filter.errors.messages }, status: :unprocessable_entity and return unless @custom_filter.valid?
  end

  def update
    @custom_filter.update!(permitted_payload)
  end

  def destroy
    @custom_filter.destroy!
    head :no_content
  end

  private

  def validate_contact_query
    payload = permitted_payload
    filter_type = payload[:filter_type] || @custom_filter.try(:filter_type)
    return unless filter_type.to_s.in?(%w[1 contact])

    query = payload.fetch(:query) { @custom_filter.try(:query) || {} }.to_h.with_indifferent_access
    return render_could_not_create_error('Invalid contact conditions') unless valid_contact_conditions?(query)

    Contacts::FilterService.new(Current.account, Current.user, query).perform
  rescue CustomExceptions::CustomFilter::InvalidAttribute,
         CustomExceptions::CustomFilter::InvalidOperator,
         CustomExceptions::CustomFilter::InvalidQueryOperator,
         CustomExceptions::CustomFilter::InvalidValue => e
    render_could_not_create_error(e.message)
  end

  def valid_contact_conditions?(query)
    conditions = query[:payload]
    return false unless conditions.is_a?(Array) && conditions.present?

    string_keys = %w[attribute_key filter_operator]
    conditions.all? do |condition|
      condition.is_a?(Hash) && condition['values'].is_a?(Array) &&
        string_keys.all? { |key| condition[key].is_a?(String) }
    end
  end

  def fetch_custom_filters
    @custom_filters = Current.account.custom_filters.where(
      user: Current.user,
      filter_type: permitted_params[:filter_type] || DEFAULT_FILTER_TYPE
    )
  end

  def fetch_custom_filter
    @custom_filter = Current.account.custom_filters.where(
      user: Current.user
    ).find(permitted_params[:id])
  end

  def permitted_payload
    params.require(:custom_filter).permit(
      :name,
      :filter_type,
      query: {}
    )
  end

  def permitted_params
    params.permit(:id, :filter_type)
  end
end

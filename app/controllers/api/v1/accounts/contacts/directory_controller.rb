class Api::V1::Accounts::Contacts::DirectoryController < Api::V1::Accounts::BaseController
  before_action -> { authorize Contact, :index? }
  before_action :validate_directory_params, only: [:index]

  def index
    directory = ::Contacts::Directory.new(Current.account, Current.user, params)
    @contacts_count = directory.scope.count
    @contacts = directory.page
    @current_page = @contacts.current_page
    @include_directory_details = true
    @include_contact_inboxes = false
    render 'api/v1/accounts/contacts/index'
  end

  def segments
    render json: { payload: ::Contacts::Segments.new(Current.account, Current.user).list }
  end

  private

  def validate_directory_params
    scalars_valid = %i[segment sort q label page].all? { |key| !params.key?(key) || params[key].is_a?(String) }
    page_valid = !params.key?(:page) || params[:page].to_s.match?(/\A[1-9]\d*\z/)
    sort_valid = ::Contacts::Directory::SORT_COLUMNS.include?(params.fetch(:sort, '-last_activity_at').to_s.delete_prefix('-'))
    return if scalars_valid && page_valid && sort_valid

    render json: { error: 'Invalid directory parameters' }, status: :unprocessable_entity
  end
end

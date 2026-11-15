class Contacts::Directory
  SORT_COLUMNS = %w[name email created_at last_activity_at conversations_count].freeze
  CONVERSATION_COUNT_SQL = '(SELECT COUNT(*) FROM conversations ' \
                           'WHERE conversations.contact_id = contacts.id ' \
                           'AND conversations.account_id = contacts.account_id) AS conversations_count'.freeze

  def initialize(account, user, params)
    @account = account
    @user = user
    @params = params
  end

  def scope
    segments = Contacts::Segments.new(@account, @user)
    id = @params.fetch(:segment, 'all')
    raise ActiveRecord::RecordNotFound unless segments.valid_reference?(id)

    contacts = segments.scope(id)
    contacts = contacts.tagged_with(@params[:label]) if @params[:label].present?
    return contacts if @params[:q].blank?

    contacts.where('contacts.name ILIKE :q OR contacts.email ILIKE :q OR contacts.phone_number ILIKE :q',
                   q: "%#{ActiveRecord::Base.sanitize_sql_like(@params[:q].strip)}%")
  end

  def page
    sort = @params.fetch(:sort, '-last_activity_at')
    attribute = sort.delete_prefix('-')
    raise ArgumentError, 'Invalid sort' unless SORT_COLUMNS.include?(attribute)

    direction = sort.start_with?('-') ? 'DESC' : 'ASC'
    column = attribute == 'conversations_count' ? attribute : "contacts.#{attribute}"
    scope.select('contacts.*', CONVERSATION_COUNT_SQL)
         .reorder(Arel.sql("#{column} #{direction} NULLS LAST, contacts.id ASC"))
         .includes(:contact_inboxes, taggings: :tag, avatar_attachment: :blob)
         .page(@params[:page]).per(Api::V1::Accounts::ContactsController::RESULTS_PER_PAGE)
  end
end

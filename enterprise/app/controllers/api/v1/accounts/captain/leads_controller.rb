require 'csv'

class Api::V1::Accounts::Captain::LeadsController < Api::V1::Accounts::BaseController
  before_action :validate_filters, only: [:index, :export]

  def index
    page = params[:page].nil? ? 1 : Integer(params[:page], exception: false)
    return render_could_not_create_error('page must be a positive integer') unless page&.positive?

    size = Captain::Leads::Directory::PAGE_SIZE
    leads = directory.ordered(params[:status])
    conversations = leads.limit(size).offset((page - 1) * size)
    render json: { payload: directory.rows(conversations), meta: { counts: directory.counts, page: page,
                                                                   total: leads.count } }
  end

  def update
    conversation = directory.scope.find_by!(display_id: params[:id])
    authorize conversation, :show?
    changes = lead_changes
    return unless changes

    conversation.with_lock do
      attributes = conversation.additional_attributes
      attributes['lead_management'] = attributes['lead_management'].to_h.merge(changes)
      conversation.update!(additional_attributes: attributes)
    end
    render json: directory.rows([conversation]).first
  end

  def export
    csv = CSV.generate do |file|
      file << ['Name', 'Email', 'Company', 'What they want', 'Type', 'Status', 'Owner', 'HubSpot', 'Captured at', 'Conversation']
      directory.filtered(params[:status]).includes(:contact).in_batches(of: 500) do |batch|
        directory.rows(batch.to_a).each do |lead|
          values = lead.values_at(:name, :email, :company, :wants, :type, :status) +
                   [lead.dig(:owner, :name), lead[:hubspot], lead[:captured_at], lead[:conversation_id]]
          file << values.map { |value| csv_cell(value) }
        end
      end
    end
    send_data csv, filename: 'leads.csv', type: 'text/csv; charset=utf-8'
  end

  private

  def directory
    @directory ||= Captain::Leads::Directory.new(Current.account, Current.user)
  end

  def lead_changes
    changes = params.permit(:status, :owner_id).to_h
    error = if changes.empty?
              'Provide a status or owner_id'
            elsif changes.key?('status') && Captain::Leads::Directory::STATUSES.exclude?(changes['status'])
              'Invalid lead status'
            elsif changes.key?('owner_id') && !valid_owner?(changes['owner_id'])
              'owner_id must be an account team member or null'
            end
    return changes unless error

    render_could_not_create_error(error)
    nil
  end

  def valid_owner?(id)
    id.nil? || (id.is_a?(Integer) && Current.account.users.exists?(id: id))
  end

  def validate_filters
    return if params[:status].nil? || params[:status] == '' || Captain::Leads::Directory::STATUSES.include?(params[:status])

    render_could_not_create_error('Invalid lead status')
  end

  # Spreadsheet applications interpret customer-supplied text beginning with these characters as formulas.
  def csv_cell(value)
    text = value.to_s
    text.match?(/\A[\s]*[=+\-@\t\r]/) ? "'#{text}" : text
  end
end

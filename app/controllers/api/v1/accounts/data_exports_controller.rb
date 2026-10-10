class Api::V1::Accounts::DataExportsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def index
    render json: Current.account.account_data_exports.order(id: :desc).limit(20).map { |export| export_payload(export) }
  end

  def show
    render json: export_payload(Current.account.account_data_exports.find(params[:id]))
  end

  def create
    return head :unprocessable_entity unless AccountDataExport::EXPORT_TYPES.include?(params[:export_type])

    export = nil
    Current.account.with_lock do
      return head :conflict if Current.account.account_data_exports.exists?(status: %w[pending processing])

      export = Current.account.account_data_exports.create!(user: Current.user, export_type: params[:export_type], expires_at: 7.days.from_now)
    end
    AccountDataExportJob.perform_later(export)
    render json: export_payload(export), status: :accepted
  end

  def download
    export = Current.account.account_data_exports.find(params[:id])
    return head :gone if export.expires_at <= Time.current
    return head :not_found unless export.completed? && export.archive.attached?

    stream_archive(export.archive.blob)
  end

  private

  def stream_archive(blob)
    response.headers['Content-Type'] = blob.content_type
    response.headers['Content-Disposition'] = ActionDispatch::Http::ContentDisposition.format(disposition: 'attachment', filename: blob.filename.to_s)
    response.headers['Cache-Control'] = 'no-store'
    self.response_body = Enumerator.new do |stream|
      blob.open do |file|
        stream << file.read(64.kilobytes) until file.eof?
      end
    end
  end

  def export_payload(export)
    export.slice(:id, :export_type, :status, :created_at, :expires_at).merge(
      filename: export.archive.attached? ? export.archive.filename.to_s : nil,
      byte_size: export.archive.attached? ? export.archive.blob.byte_size : nil
    )
  end
end

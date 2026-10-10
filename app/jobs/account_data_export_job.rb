require 'zip'
require 'tempfile'

class AccountDataExportJob < ApplicationJob
  queue_as :low

  def perform(export)
    return if export.completed?

    if export.expires_at <= Time.current || !export.account.account_users.exists?(user: export.user, role: :administrator)
      export.failed!
      return
    end

    export.processing!
    attach_archive(export)
    export.completed!
    AccountDataExportCleanupJob.set(wait_until: export.expires_at).perform_later(export)
  rescue StandardError => e
    export.archive.purge if export.archive.attached?
    export.failed!
    Rails.logger.warn("Account export #{export.id} failed (#{e.class.name})")
    # Export content and upstream errors can contain private account data; only log the error class.
  end

  private

  def attach_archive(export)
    Tempfile.create(['account-export', '.zip']) do |file|
      Zip::OutputStream.open(file.path) do |zip|
        AccountDataExportService.new(export: export, zip: zip).perform
      end
      File.open(file.path, 'rb') do |archive|
        name = export.account.name.parameterize.presence || "account-#{export.account_id}"
        filename = "#{name}-#{export.export_type}-#{export.created_at.strftime('%Y-%m-%d')}-#{export.id}.zip"
        export.archive.attach(io: archive, filename: filename, content_type: 'application/zip')
      end
    end
  end
end

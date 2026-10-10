require 'rubygems/package'
require 'zlib'
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
    Tempfile.create(['account-export', '.tar.gz']) do |file|
      file.binmode
      Zlib::GzipWriter.wrap(file) do |gzip|
        Gem::Package::TarWriter.new(gzip) do |tar|
          AccountDataExportService.new(export: export, tar: tar).perform
        end
      end
      File.open(file.path, 'rb') do |archive|
        export.archive.attach(io: archive, filename: "account-#{export.account_id}-#{export.id}.tar.gz", content_type: 'application/gzip')
      end
    end
  end
end

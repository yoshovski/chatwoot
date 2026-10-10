class AccountDataExport < ApplicationRecord
  EXPORT_TYPES = %w[conversations contacts knowledge all].freeze
  belongs_to :account
  belongs_to :user
  has_one_attached :archive
  validates :export_type, inclusion: { in: EXPORT_TYPES }
  enum :status, { pending: 'pending', processing: 'processing', completed: 'completed', failed: 'failed' }
end

class Captain::DocumentAnalysis < ApplicationRecord
  self.table_name = 'captain_document_analyses'
  STATUSES = %w[pending analyzing analyzed partial excluded failed stale].freeze
  ROLES = %w[product service pricing support policy company partner marketing technical other].freeze

  belongs_to :account
  belongs_to :assistant, class_name: 'Captain::Assistant'
  belongs_to :document, class_name: 'Captain::Document'

  before_validation -> { self.account ||= assistant&.account || document&.account }
  validates :content_fingerprint, presence: true
  validates :status, inclusion: { in: STATUSES }

  alias_attribute :extracted_offerings, :offerings

  def page_role
    Array(page_roles).first
  end
end

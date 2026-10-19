class Captain::WebsiteSource < ApplicationRecord
  self.table_name = 'captain_website_sources'

  belongs_to :account
  belongs_to :assistant, class_name: 'Captain::Assistant'

  before_validation -> { self.account = assistant.account if assistant }
  before_validation -> { self.url = Captain::Websites::UrlPolicy.normalize(url) }
  validates :url, presence: true, length: { maximum: 2048 }
  validates :status, inclusion: { in: %w[pending discovering ready failed] }
  validate :validate_url, if: :will_save_change_to_url?

  def selectable_urls
    pages.reject { |page| page['blocked_reason'].present? }.pluck('url')
  end

  def client_payload
    documents = assistant.documents.where(external_link: pages.pluck('url')).index_by(&:external_link)
    as_json(only: %i[id url include_subdomains status selected_urls discovery_stats error_code discovered_at]).merge(
      'recoverable' => status.in?(%w[pending discovering]) && updated_at < 2.hours.ago,
      'pages' => pages.map do |page|
        document = documents[page['url']]
        page.merge('document_id' => document&.id, 'sync_status' => document&.sync_status,
                   'knowledge_state' => document&.knowledge_state, 'enabled' => document&.enabled?,
                   'error_code' => document&.last_sync_error_code)
      end
    )
  end

  private

  def validate_url
    uri = URI.parse(url.to_s)
    valid_http = uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil? && uri.port == uri.default_port
    return if valid_http && Captain::Document.new(external_link: uri.to_s).customer_visible_source_url.present?

    errors.add(:url, :invalid)
  rescue URI::InvalidURIError
    errors.add(:url, :invalid)
  end
end

class Captain::WebsiteSource < ApplicationRecord
  self.table_name = 'captain_website_sources'
  # Kept for classification and duplicate checks; the page picker does not need them.
  SERVER_ONLY_PAGE_FIELDS = %w[description fingerprint minhash canonical schema help_center_article_id markdown_url updated_at].freeze
  # Pages that can never become knowledge. They stay stored, so rediscovery does not offer them again,
  # but the picker only shows how many were left out.
  HIDDEN_REASONS = %w[not_found thin not_html].freeze

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
    hidden, visible = pages.partition { |page| HIDDEN_REASONS.include?(page['reason']) }
    as_json(only: %i[id url include_subdomains status selected_urls error_code discovered_at]).merge(
      'discovery_stats' => client_stats,
      'recoverable' => status.in?(%w[pending discovering]) && updated_at < 2.hours.ago,
      'documents_available' => account.usage_limits[:captain][:documents][:current_available],
      'hidden_pages' => hidden.size,
      'pages' => pages_payload(visible)
    )
  end

  # Boilerplate block hashes are only used server-side. A page labelled on its own is a one-page
  # section, so the picker shows its label like any section's.
  def client_stats
    page_labels = discovery_stats['page_labels'] || {}
    labelled = pages.filter_map { |page| [page['section'], page_labels[page['url']]] if page_labels.key?(page['url']) }.to_h
    discovery_stats.except('boilerplate', 'boilerplate_sections', 'page_labels')
                   .merge('sections' => labelled.merge(discovery_stats['sections'] || {}))
  end

  private

  def pages_payload(visible)
    documents = assistant.documents.where(external_link: visible.pluck('url')).index_by(&:external_link)
    visible.map { |page| page_payload(page, documents[page['url']]) }
  end

  def page_payload(page, document)
    page.except(*SERVER_ONLY_PAGE_FIELDS).merge('document_id' => document&.id, 'sync_status' => document&.sync_status,
                                                'knowledge_state' => document&.knowledge_state, 'enabled' => document&.enabled?,
                                                'error_code' => document&.last_sync_error_code)
  end

  def validate_url
    uri = URI.parse(url.to_s)
    valid_http = uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil? && uri.port == uri.default_port
    return if valid_http && Captain::Document.new(external_link: uri.to_s).customer_visible_source_url.present?

    errors.add(:url, :invalid)
  rescue URI::InvalidURIError
    errors.add(:url, :invalid)
  end
end

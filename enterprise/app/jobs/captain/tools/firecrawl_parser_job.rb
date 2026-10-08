class Captain::Tools::FirecrawlParserJob < ApplicationJob
  queue_as :low

  def perform(assistant_id:, payload:)
    assistant = Captain::Assistant.find(assistant_id)
    payload_data = payload.respond_to?(:with_indifferent_access) ? payload.with_indifferent_access : payload
    metadata = payload_data[:metadata] || {}

    canonical_url = normalize_link(metadata['sourceURL'].presence || metadata['url'])
    document = assistant.documents.find_or_initialize_by(external_link: canonical_url)

    content, faqs = parse_payload(payload_data, metadata['title'])
    update_document!(document, canonical_url, metadata['title'], content, faqs)
  rescue StandardError => e
    raise "Failed to parse FireCrawl data: #{e.message}"
  end

  private

  def parse_payload(payload_data, title)
    content = payload_data[:markdown]
    faqs = []

    if payload_data[:html].present?
      parser = Captain::Tools::HtmlPageParser.new(payload_data[:html])
      faqs = parser.faqs
      content = parser.body_markdown_without_faqs.presence || content
    end

    content = content.presence || title.presence || ''
    [content[0...Captain::Documents::SinglePageFetcher::CONTENT_MAX_LENGTH], faqs]
  end

  def update_document!(document, canonical_url, title, content, faqs)
    doc_metadata = (document.metadata || {}).merge('page_faqs' => faqs)

    document.update!(
      external_link: canonical_url,
      content: content,
      metadata: doc_metadata,
      name: title,
      status: :available,
      sync_status: :synced,
      last_synced_at: Time.current,
      last_sync_attempted_at: Time.current,
      last_sync_error_code: nil
    )
  end

  def normalize_link(raw_url)
    raw_url.to_s.delete_suffix('/')
  end
end

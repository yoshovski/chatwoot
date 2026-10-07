class Captain::Documents::CrawlJob < ApplicationJob
  queue_as :low

  def perform(document)
    return perform_pdf_processing(document) if document.pdf_document?

    scope = Captain::Documents::CrawlScope.new(document)
    if !scope.follow_links?
      crawl_page(document, document.external_link)
    elsif InstallationConfig.find_by(name: 'CAPTAIN_FIRECRAWL_API_KEY')&.value.present?
      perform_firecrawl_crawl(document, scope)
    else
      perform_simple_crawl(document, scope)
    end
  rescue StandardError
    # Without this the document stays "in progress" forever and offers no retry.
    mark_crawl_failed(document) unless document.pdf_document?
    raise
  end

  private

  def mark_crawl_failed(document)
    document.update!(status: :available, sync_status: :failed, last_sync_error_code: 'fetch_failed', last_sync_attempted_at: Time.current)
  end

  include Captain::FirecrawlHelper

  def perform_pdf_processing(document)
    Captain::Llm::PdfProcessingService.new(document).process
    document.update!(status: :available)
  rescue StandardError => e
    Rails.logger.error I18n.t('captain.documents.pdf_processing_failed', document_id: document.id, error: e.message)
    raise # Re-raise to let job framework handle retry logic
  end

  def perform_simple_crawl(document, scope)
    page_links = Captain::Tools::SimplePageCrawlService.new(document.external_link).page_links.select { |link| scope.follow?(link) }
    page_links.each { |page_link| crawl_page(document, page_link) }
    crawl_page(document, document.external_link)
  end

  def crawl_page(document, page_link)
    Captain::Tools::SimplePageCrawlParserJob.perform_later(assistant_id: document.assistant_id, page_link: page_link)
  end

  def perform_firecrawl_crawl(document, scope)
    captain_usage_limits = document.account.usage_limits[:captain] || {}
    document_limit = captain_usage_limits[:documents] || {}
    crawl_limit = [document_limit[:current_available] || 10, 500].min

    Captain::Tools::FirecrawlService
      .new
      .perform(
        document.external_link,
        firecrawl_webhook_url(document),
        crawl_limit,
        include_paths: scope.firecrawl_include_paths
      )
  end

  def firecrawl_webhook_url(document)
    webhook_url = Rails.application.routes.url_helpers.enterprise_webhooks_firecrawl_url

    "#{webhook_url}?assistant_id=#{document.assistant_id}&token=#{generate_firecrawl_token(document.assistant_id, document.account_id)}"
  end
end

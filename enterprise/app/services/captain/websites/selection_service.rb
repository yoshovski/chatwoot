class Captain::Websites::SelectionService
  class InvalidSelection < StandardError; end

  def initialize(source)
    @source = source
    @assistant = source.assistant
  end

  def perform(urls)
    raise InvalidSelection, I18n.t('captain.websites.discovery_pending') unless @source.status == 'ready'
    raise InvalidSelection, I18n.t('captain.websites.invalid_selection') unless urls.is_a?(Array) && urls.all?(String)

    @source.account.with_lock do
      @source.lock!
      raise InvalidSelection, I18n.t('captain.websites.discovery_pending') unless @source.status == 'ready'
      raise InvalidSelection, I18n.t('captain.websites.invalid_selection') unless (urls - @source.selectable_urls).empty?

      apply_selection(urls.uniq)
    end
    @source.reload
  end

  private

  def apply_selection(urls)
    existing = @assistant.documents.where(external_link: urls).index_by(&:external_link)
    needed = urls.size - existing.size
    available = @source.account.usage_limits[:captain][:documents][:current_available]
    raise Captain::Document::LimitExceededError, I18n.t('captain.documents.limit_exceeded') if needed > available

    deselect_documents(urls)
    @source.update!(selected_urls: urls)
    urls.each_with_index { |url, index| include_document(url, existing[url], index) }
  end

  def include_document(url, document, index)
    wait = index * Captain::Documents::CrawlJob::PAGE_STAGGER
    unless document
      @assistant.documents.create!(external_link: url, name: url.first(Captain::Documents::SinglePageFetcher::TITLE_MAX_LENGTH),
                                   metadata: { 'website_source_id' => @source.id, 'include_linked_pages' => false,
                                               'website_import_delay' => wait.to_i })
      return
    end
    return if document.metadata.to_h['website_source_id'].blank?

    document.update!(enabled: true) unless document.enabled?
    Captain::Websites::ImportPageJob.set(wait: wait).perform_later(document.id) if document.content.blank?
  end

  def deselect_documents(urls)
    removed = @source.selected_urls - urls
    @assistant.documents.where(external_link: removed).find_each do |document|
      # Existing manual sources are never disabled by website selection.
      next if document.metadata.to_h['website_source_id'].blank?
      next if @assistant.website_sources.where.not(id: @source.id).exists?(['selected_urls @> ?::jsonb', [document.external_link].to_json])

      document.update!(enabled: false)
    end
  end
end

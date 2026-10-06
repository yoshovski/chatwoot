class Captain::Knowledge::CitationSources
  def initialize(assistant)
    @assistant = assistant
  end

  def urls(references, details: {}, allowed_product_handles: nil)
    references.transform_values do |reference|
      url(reference, details[reference] || details[reference.to_s], allowed_product_handles: allowed_product_handles)
    end.compact.transform_keys(&:to_i)
  end

  def url(reference, detail = nil, allowed_product_handles: nil)
    return product_url(reference, allowed_handles: allowed_product_handles) if reference.to_s.start_with?('product:')

    document = source_document(reference)
    return document_url(document) if document

    extra_url(reference, detail)
  end

  def product_url(reference, allowed_handles: nil)
    handle = reference.to_s.delete_prefix('product:').strip
    return if handle.blank?
    return if allowed_handles.present? && allowed_handles.map(&:to_s).map(&:downcase).exclude?(handle.downcase)

    base_url = connected_storefront_url
    return if base_url.blank?

    "#{base_url.chomp('/')}/products/#{handle}"
  end

  def source_document(reference)
    type, id = source_identity(reference)
    document = case type
               when 'doc' then @assistant.documents.find_by(id: id)
               when 'faq' then @assistant.responses.approved.find_by(id: id)&.documentable
               end
    document if owned_document?(document)
  end

  def allowed_url(value)
    return unless @assistant.config.fetch('dify_citation_allowed_origins', []).include?(self.class.origin_for(value))

    Captain::Document.new(external_link: value).customer_visible_source_url
  end

  def self.origin_for(value)
    return if value.blank?

    uri = URI.parse(value)
    return unless uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil?

    port = uri.port == uri.default_port ? '' : ":#{uri.port}"
    "#{uri.scheme}://#{uri.host}#{port}"
  rescue URI::InvalidURIError
    nil
  end

  private

  def extra_url(reference, detail)
    return unless reference.to_s.start_with?('extra:') && detail
    return unless @assistant.config.fetch('dify_extra_dataset_ids', []).include?(detail.fetch(:dataset_id) { detail['dataset_id'] })

    allowed_url(detail.fetch(:url) { detail['url'] })
  end

  def connected_storefront_url
    hook = @assistant.account.hooks.find_by(app_id: 'shopify')
    return unless hook&.shopify_connected?

    url = hook.shopify_storefront_url.presence || "https://#{hook.reference_id}"
    url = "https://#{url}" unless url.to_s.start_with?('http://', 'https://')
    url
  end

  def source_identity(reference)
    return ['doc', reference] if reference.to_s.match?(/\A\d+\z/)

    match = reference.to_s.match(/\A(faq|doc):(\d+)\z/)
    [match&.[](1), match&.[](2)]
  end

  def owned_document?(document)
    document.present? && document.is_a?(Captain::Document) &&
      document.account_id == @assistant.account_id &&
      document.assistant_id == @assistant.id
  end

  def document_url(document)
    document.customer_visible_source_url || allowed_url(document.metadata.to_h['source_url'])
  end
end

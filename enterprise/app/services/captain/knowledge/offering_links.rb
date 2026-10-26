# Restore useful product-name links from published, currently public evidence only.
class Captain::Knowledge::OfferingLinks
  PROTECTED_MARKUP = %r{(```.*?```|`[^`]*`|!?\[[^\]]*\]\([^\s]*\)|https?://[^\s<>]+)}m

  def initialize(assistant)
    @assistant = assistant
  end

  def perform(content)
    return content if @assistant.config['helpful_links_mode'] == 'on_request'
    return content unless @assistant.config['knowledge_brief_enabled'] == true

    brief = @assistant.knowledge_brief
    return content unless brief&.usable?(brief.published)

    offerings = brief.usable_offerings(brief.published)
    ids = offerings.flat_map { |item| Array(item['evidence']).pluck('document_id') }.uniq
    documents = brief.permitted_documents(ids).index_by(&:id)
    offerings.reduce(content) { |text, offering| link_offering(text, offering, documents) }
  end

  private

  def link_offering(text, offering, documents)
    name = offering['name'].to_s
    return text if name.blank? || text.exclude?(name)

    url = offering_url(offering, documents)
    return text if url.blank? || text.include?(url)

    link_first_name(text, name, url)
  end

  def offering_url(offering, documents)
    name = offering.fetch('name').downcase
    sources = Array(offering['evidence']).filter_map { |item| documents[item['document_id'].to_i] }
    document = sources.find { |item| item.name.to_s.downcase.include?(name) } || sources.first
    url = document&.customer_visible_source_url
    return if url.blank?

    url if Captain::Conversation::ReplySanitizer.new(assistant: @assistant, evidence_urls: [url]).allowed_link_url?(url)
  end

  def link_first_name(text, name, url)
    linked = false
    text.split(PROTECTED_MARKUP).map do |part|
      next part if linked || part.match?(/\A#{PROTECTED_MARKUP}\z/o)

      part.sub(/(?<![[:alnum:]_])#{Regexp.escape(name)}(?![[:alnum:]_])/) do |match|
        linked = true
        "[#{match.tr('[]', '()')}](#{url.gsub('(', '%28').gsub(')', '%29')})"
      end
    end.join
  end
end

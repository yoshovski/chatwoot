class Captain::Knowledge::OfferingEnumerator
  include Captain::Tools::SourceIndexing

  PAGE_SIZE = 20
  DEFAULT_KINDS = %w[product service].freeze
  ENUMERATION_PATTERN = /\b(?:all|every|complete\s+list|full\s+list|list\s+(?:of\s+)?(?:all\s+)?(?:your\s+|the\s+|our\s+)?|
                           what\s+are\s+(?:all\s+)?(?:your|the)|tell\s+me\s+all(?:\s+of)?(?:\s+your)?|enumerate)\b
                         .*\b(?:products?|services?|offerings?|solutions?|plans?|tiers?|packages?|features?|add-?ons?)\b/xi
  NEXT_PAGE_PATTERN = /\b(?:next\s+page|show\s+more|more\s+(?:products?|services?|offerings?|plans?|features?)|page\s+(\d+))\b/i
  PLAN_PATTERN = /\b(?:plans?|tiers?|packages?)\b/i
  FEATURE_PATTERN = /\b(?:features?|capabilities)\b/i
  ADD_ON_PATTERN = /\badd-?ons?\b/i
  PRODUCT_SERVICE_PATTERN = /\b(?:products?|services?|offerings?|solutions?)\b/i

  EXCLUDED_STATUSES = %w[rejected candidate review].freeze
  KIND_PATTERNS = {
    'plan' => PLAN_PATTERN,
    'feature' => FEATURE_PATTERN,
    'add_on' => ADD_ON_PATTERN
  }.freeze

  def self.enumeration_request?(message, route = {}, state = {})
    return true if route.is_a?(Hash) && route['mode'] == 'enumeration'

    text = message.to_s.strip
    return false if text.blank?
    return true if text.match?(ENUMERATION_PATTERN)

    text.match?(NEXT_PAGE_PATTERN) && (text.match?(/\bpage\s+\d+\b/i) || state[:offering_enumeration_cursor].present?)
  end

  def self.requested_kinds(message, route = {})
    routed = routed_kinds(route)
    return routed if routed.any?

    matched_kinds_from_text(message.to_s)
  end

  def self.routed_kinds(route)
    return [] unless route.is_a?(Hash) && route['offering_kinds'].is_a?(Array)

    route['offering_kinds'].map(&:to_s) & Captain::Knowledge::OfferingReconciler::OFFERING_KINDS
  end

  def self.matched_kinds_from_text(text)
    kinds = text.match?(PRODUCT_SERVICE_PATTERN) ? DEFAULT_KINDS.dup : []
    KIND_PATTERNS.each { |kind, pattern| kinds << kind if text.match?(pattern) }
    kinds.presence&.uniq || DEFAULT_KINDS
  end

  def self.requested_page(message, route = {}, state = {})
    return route['page'].to_i if route.is_a?(Hash) && route['page'].to_i.positive?

    text = message.to_s
    if (cursor_match = text.match(/\[cursor:(\d+)\]/i))
      return (cursor_match[1].to_i / PAGE_SIZE) + 1
    end
    if (match = text.match(/\bpage\s+(\d+)\b/i))
      return [match[1].to_i, 1].max
    end
    return state[:offering_enumeration_cursor].to_i if text.match?(NEXT_PAGE_PATTERN) && state[:offering_enumeration_cursor].to_i.positive?

    1
  end

  def initialize(positional_assistant = nil, assistant: nil, query: nil, page_size: PAGE_SIZE)
    @assistant = assistant || positional_assistant
    @query = query
    @page_size = page_size
  end

  def usable_offerings(kinds: DEFAULT_KINDS)
    brief = @assistant.knowledge_brief
    return [] unless @assistant.config['knowledge_brief_enabled'] == true && brief&.usable?(brief.published)

    entries = filter_offerings_by_kind(brief.usable_offerings(brief.published), kinds)
    entries.uniq { |item| item['id'] }.sort_by do |item|
      [Captain::Knowledge::OfferingReconciler::OFFERING_KINDS.index(item['kind']) || 99, item['name'].to_s.downcase, item['id'].to_s]
    end
  end

  def perform(tool_context = nil, message: @query, route: {})
    tool_context ||= Struct.new(:state).new({})
    entries = usable_offerings(kinds: self.class.requested_kinds(message, route))
    return if entries.empty?

    page_info = paginate_entries(entries, self.class.requested_page(message, route, tool_context.state))
    documents = load_documents(page_info[:slice])
    record_documents(tool_context, documents.keys)
    parts = build_response_parts(tool_context, documents, page_info)
    record_enumeration_state(tool_context.state, page_info)
    build_enumeration_result(parts, documents, page_info)
  end

  private

  def filter_offerings_by_kind(offerings, kinds)
    offerings.select { |item| EXCLUDED_STATUSES.exclude?(item['status']) && kinds.include?(item['kind']) }
  end

  def paginate_entries(entries, raw_page)
    total = entries.size
    total_pages = (total.to_f / @page_size).ceil
    page = raw_page.clamp(1, total_pages)
    offset = (page - 1) * @page_size
    slice = entries.slice(offset, @page_size) || []
    { slice: slice, page: page, total: total, total_pages: total_pages, offset: offset }
  end

  def record_enumeration_state(state, page_info)
    state[:enumerated_offering_ids] = page_info[:slice].pluck('id')
    state[:offering_enumeration_cursor] = page_info[:page] < page_info[:total_pages] ? page_info[:page] + 1 : nil
    state[:offering_enumeration_total] = page_info[:total]
  end

  def build_enumeration_result(parts, documents, page_info)
    next_suggestions = pagination_suggestions(
      page_info[:page], page_info[:total], page_info[:total_pages], page_info[:offset] + page_info[:slice].size
    )
    plain = parts.pluck('text').join("\n")
    {
      'response' => plain, 'response_parts' => parts, 'suggested_replies' => next_suggestions, 'handoff_requested' => false,
      :response => plain,
      :sources => documents.values.map { |d| { id: d.id, title: d.name, url: d.external_link } },
      :suggested_replies => next_suggestions
    }
  end

  def load_documents(offerings)
    ids = offerings.flat_map { |item| Array(item['evidence']).pluck('document_id') }.uniq
    @assistant.documents.enabled.where(agents_only: false, id: ids).index_by(&:id)
  end

  def record_documents(tool_context, ids)
    metadata = tool_context.state[:cw_metadata] ||= {}
    metadata[:document_ids] = Array(metadata[:document_ids]) | ids
  end

  def build_response_parts(tool_context, documents, page_info)
    item_parts = page_info[:slice].map do |offering|
      indexes = register_offering_evidence(tool_context, offering, documents)
      {
        'text' => "- #{offering_title(offering, documents)}: #{offering.fetch('purpose')}",
        'citation_indexes' => indexes
      }
    end
    all_indexes = item_parts.flat_map { |part| part['citation_indexes'] }.uniq
    intro = intro_text(page_info[:slice].size, **page_info.slice(:page, :total, :total_pages, :offset))
    [{ 'text' => intro, 'citation_indexes' => all_indexes }] + item_parts
  end

  def offering_title(offering, documents)
    name = offering.fetch('name').tr('[]', '()')
    return "**#{name}**" if @assistant.config['helpful_links_mode'] == 'on_request'

    urls = Array(offering['evidence']).filter_map { |item| documents[item['document_id'].to_i]&.customer_visible_source_url }
    url = urls.first
    return "**#{name}**" unless url

    sanitizer = Captain::Conversation::ReplySanitizer.new(assistant: @assistant, evidence_urls: urls)
    return "**#{name}**" unless sanitizer.allowed_link_url?(url)

    "[**#{name}**](#{url.gsub('(', '%28').gsub(')', '%29')})"
  end

  def register_offering_evidence(tool_context, offering, documents)
    Array(offering['evidence']).filter_map do |ev|
      doc = documents[ev['document_id'].to_i]
      next unless doc

      quote = ev['quote'].to_s.presence || offering['purpose'].to_s
      source_index_for(
        tool_context,
        "doc:#{doc.id}",
        { kind: 'document', title: doc.name, document_id: doc.id, excerpt: source_excerpt(quote) }
      )
    end.uniq
  end

  def intro_text(count, page:, total:, total_pages:, offset:)
    if total_pages > 1
      first_num = offset + 1
      last_num = offset + count
      more_note = page < total_pages ? " Ask for page #{page + 1} to see the next set." : ''
      "Showing #{first_num}–#{last_num} of #{total} products and services (page #{page} of #{total_pages}).#{more_note}"
    else
      'Our products and services include:'
    end
  end

  def pagination_suggestions(page, total, total_pages, next_cursor)
    return [] unless page < total_pages

    next_end = [next_cursor + @page_size, total].min
    [
      {
        'label' => "More (#{next_cursor + 1}–#{next_end})",
        'message' => "Show remaining offerings (#{next_cursor + 1}–#{next_end}) [cursor:#{next_cursor}]"
      }
    ]
  end
end

class Captain::Knowledge::OfferingReconciler # rubocop:disable Metrics/ClassLength
  OFFERING_KINDS = %w[product service plan feature add_on].freeze
  PRIMARY_KINDS = %w[product service].freeze
  OFFERING_STATUSES = %w[approved auto owner_edited candidate rejected review].freeze
  NAME_MAX_LENGTH = 120
  PURPOSE_MAX_LENGTH = 300
  QUOTE_MAX_LENGTH = 600
  PASSAGE_MIN_LENGTH = 20
  PASSAGE_MAX_LENGTH = 2000
  MAX_PASSAGES_PER_DOCUMENT = 60
  PROACTIVE_EXCLUSION_PATTERN = /\b(?:cancel(?:lation)?|refunds?|close\s+(?:my\s+)?account|delete\s+(?:my\s+)?account|terminate)\b/i

  def self.passages_for(document)
    content = document.content.to_s
    return { passages: [], total_sections: 0, inspected_sections: 0, partial: false } if content.blank?

    filtered = extract_filtered_passages(content, document.name.presence || 'Source document')
    inspected = filtered.first(MAX_PASSAGES_PER_DOCUMENT)
    {
      passages: inspected.each_with_index.map { |text, idx| { 'id' => "p#{idx}", 'text' => text.first(PASSAGE_MAX_LENGTH) } },
      total_sections: filtered.size,
      inspected_sections: inspected.size,
      partial: filtered.size > inspected.size
    }
  end

  def self.extract_filtered_passages(content, title)
    sectioned = Captain::Knowledge::SectionedText.new(content, title: title, infer_plain_titles: false).to_s
    all_passages = sectioned.split(Captain::Knowledge::SectionedText::SECTION_SEPARATOR).flat_map do |section|
      body = section.lines.drop(1).join.strip
      body.split(/\n\s*\n+/).presence || [body]
    end
    filtered = all_passages.map(&:strip).select { |part| part.length >= PASSAGE_MIN_LENGTH }
    filtered.presence || [content.strip.first(PASSAGE_MAX_LENGTH)]
  end
  private_class_method :extract_filtered_passages

  def self.evidence_supported?(evidence, document)
    return false unless valid_evidence_target?(evidence, document)

    quote = evidence['quote'].to_s.strip
    doc_content = document.content.to_s
    fingerprint = Digest::SHA256.hexdigest(doc_content)
    return true if evidence['content_fingerprint'] == fingerprint && doc_content.include?(quote)

    normalize_whitespace(doc_content).include?(normalize_whitespace(quote))
  end

  def self.valid_evidence_target?(evidence, document)
    evidence.is_a?(Hash) && evidence['quote'].to_s.strip.present? &&
      document&.enabled? && !document.agents_only? && document.content.to_s.present?
  end
  private_class_method :valid_evidence_target?

  def self.normalize_whitespace(text)
    text.to_s.gsub(/\s+/, ' ').strip
  end

  def self.canonical_key(text)
    text.to_s.downcase.gsub(/[^[:alnum:]]+/, ' ').strip
  end

  def self.stable_id(name, kind = 'product')
    slug = name.to_s.parameterize
    slug.presence || "#{kind}-#{Digest::SHA256.hexdigest(name.to_s).first(8)}"
  end

  def initialize(documents:, existing_draft: {}, existing_published: {})
    @documents_by_id = Array(documents).index_by(&:id)
    @passages_by_doc_id = @documents_by_id.transform_values { |doc| self.class.passages_for(doc)[:passages] }
    @existing_overlays = index_existing_overlays(existing_published, existing_draft)
  end

  def reconcile(raw_offerings)
    verified = Array(raw_offerings).filter_map { |item| normalize_and_verify(item) }
    merged = merge_entries(verified)
    apply_overlays(merged)
  end

  def self.build_suggestion_candidates(offerings, topics, fallback_document_ids = [])
    usable_offerings = Array(offerings).reject { |item| item['status'] == 'rejected' }
    candidates = category_candidates(usable_offerings) +
                 offering_candidates(usable_offerings) +
                 topic_candidates(topics, fallback_document_ids)
    deduplicate_candidates(candidates)
  end

  def self.category_candidates(usable_offerings)
    primary_offerings = usable_offerings.select { |item| PRIMARY_KINDS.include?(item['kind']) }
    return [] unless primary_offerings.size > 1

    doc_ids = primary_offerings.flat_map { |item| Array(item['evidence']).pluck('document_id') }.uniq
    [
      build_candidate(
        id: 'explore-offerings', title: 'All products & services',
        message: 'What products and services do you offer?',
        target_kind: 'category', target_id: 'all-offerings', document_ids: doc_ids
      )
    ]
  end
  private_class_method :category_candidates

  def self.offering_candidates(usable_offerings)
    usable_offerings.filter_map do |offering|
      next if offering['name'].to_s.match?(PROACTIVE_EXCLUSION_PATTERN)

      doc_ids = Array(offering['evidence']).pluck('document_id').uniq
      next if doc_ids.empty?

      build_candidate(
        id: "offering-#{offering['id']}",
        title: offering['name'].to_s.strip.truncate(Captain::ResponseSchema::SUGGESTION_LABEL_MAX_LENGTH, separator: ' '),
        message: "Tell me about #{offering['name']}.".truncate(Captain::ResponseSchema::SUGGESTION_MESSAGE_MAX_LENGTH),
        target_kind: 'offering', target_id: offering['id'], document_ids: doc_ids
      )
    end
  end
  private_class_method :offering_candidates

  def self.topic_candidates(topics, fallback_document_ids)
    Array(topics).filter_map { |topic| single_topic_candidate(topic, fallback_document_ids) }
  end
  private_class_method :topic_candidates

  def self.single_topic_candidate(topic, fallback_document_ids)
    return unless topic.is_a?(Hash) && topic['title'].present? && !topic['title'].to_s.match?(PROACTIVE_EXCLUSION_PATTERN)

    doc_ids = Array(topic['document_ids']).presence || fallback_document_ids
    return if doc_ids.empty?

    title = topic['title'].to_s.strip
    slug = title.parameterize.presence || Digest::SHA256.hexdigest(title).first(8)
    build_candidate(
      id: "topic-#{slug}",
      title: title.truncate(Captain::ResponseSchema::SUGGESTION_LABEL_MAX_LENGTH, separator: ' '),
      message: "How does #{title} work?".truncate(Captain::ResponseSchema::SUGGESTION_MESSAGE_MAX_LENGTH),
      target_kind: 'topic', target_id: slug, document_ids: doc_ids
    )
  end
  private_class_method :single_topic_candidate

  def self.build_candidate(**attrs)
    {
      'id' => attrs.fetch(:id),
      'title' => attrs.fetch(:title),
      'message' => attrs.fetch(:message),
      'target_kind' => attrs.fetch(:target_kind),
      'target_id' => attrs.fetch(:target_id),
      'document_ids' => Array(attrs.fetch(:document_ids)).uniq
    }
  end
  private_class_method :build_candidate

  def self.deduplicate_candidates(candidates)
    seen_titles = Set.new
    seen_messages = Set.new
    candidates.select do |item|
      title_key = canonical_key(item['title'])
      msg_key = canonical_key(item['message'])
      title_key.present? && msg_key.present? && seen_titles.add?(title_key) && seen_messages.add?(msg_key)
    end
  end
  private_class_method :deduplicate_candidates

  private

  def index_existing_overlays(published, draft)
    entries = Array(published.to_h['offerings']) + Array(draft.to_h['offerings'])
    entries.each_with_object({}) do |item, acc|
      next unless item.is_a?(Hash) && item['id'].present?

      acc[item['id']] = item if item['edited'] == true || item['status'].in?(%w[owner_edited rejected]) || !acc.key?(item['id'])
    end
  end

  def normalize_and_verify(item)
    return if !item.is_a?(Hash) || item['partner_or_example'] == true

    name = Captain::Knowledge::BriefGenerator.clean_text(item['name'].to_s, NAME_MAX_LENGTH)
    purpose = Captain::Knowledge::BriefGenerator.clean_text(item['purpose'].to_s, PURPOSE_MAX_LENGTH)
    return if name.blank? || purpose.blank?

    evidence = verify_evidence_list(item['evidence'], item['document_ids'])
    return if evidence.empty?

    build_normalized_offering(item, name, purpose, evidence)
  end

  def build_normalized_offering(item, name, purpose, evidence)
    kind = normalize_kind(item['kind'])
    {
      'id' => item['id'].to_s.strip.presence || self.class.stable_id(name, kind),
      'name' => name,
      'kind' => kind,
      'aliases' => clean_string_list(item['aliases'], 80),
      'category_ids' => clean_string_list(item['category_ids'], 80).map { |c| c.parameterize.presence || c },
      'purpose' => purpose,
      'audiences' => clean_string_list(item['audiences'], 80),
      'status' => OFFERING_STATUSES.include?(item['status']) ? item['status'] : 'approved',
      'edited' => item['edited'] == true,
      'evidence' => evidence
    }
  end

  def normalize_kind(raw_kind)
    kind = raw_kind.to_s.strip.downcase.tr('-', '_')
    OFFERING_KINDS.include?(kind) ? kind : 'product'
  end

  def clean_string_list(values, max_len)
    Array(values).filter_map { |val| val.to_s.strip.first(max_len).presence }.uniq
  end

  def verify_evidence_list(raw_evidence, fallback_doc_ids)
    items = Array(raw_evidence).filter_map { |ev| verify_single_evidence(ev) }
    return items.uniq { |ev| [ev['document_id'], ev['passage_id'], ev['quote']] } if items.any?

    Array(fallback_doc_ids).filter_map { |doc_id| fallback_evidence_for_doc(doc_id) }.first(2)
  end

  def verify_single_evidence(evidence_item)
    return unless evidence_item.is_a?(Hash)

    doc = @documents_by_id[evidence_item['document_id'].to_i]
    return unless doc && doc.content.present?

    passage = resolve_passage(evidence_item, @passages_by_doc_id[doc.id] || [], doc.content)
    return unless passage

    {
      'document_id' => doc.id,
      'content_fingerprint' => Digest::SHA256.hexdigest(doc.content.to_s),
      'passage_id' => passage['id'],
      'quote' => passage['text'].first(QUOTE_MAX_LENGTH),
      'supports' => clean_string_list(evidence_item['supports'], 40).presence || %w[name purpose]
    }
  end

  def resolve_passage(evidence_item, passages, raw_content)
    quote = evidence_item['quote'].to_s.strip
    found = find_passage_by_id(evidence_item['passage_id'], passages)
    return found if quote.blank?

    resolve_quoted_passage(quote, found, passages, raw_content)
  end

  def find_passage_by_id(raw_id, passages)
    passage_id = raw_id.to_s.strip
    return if passage_id.blank?

    normalized_id = passage_id.match?(/\A\d+\z/) ? "p#{passage_id}" : passage_id
    passages.find { |p| p['id'] == normalized_id }
  end

  def resolve_quoted_passage(quote, found, passages, raw_content)
    norm_quote = self.class.normalize_whitespace(quote)
    return unless self.class.normalize_whitespace(raw_content).include?(norm_quote)
    return { 'id' => found['id'], 'text' => quote } if found && self.class.normalize_whitespace(found['text']).include?(norm_quote)

    matched = passages.find { |p| self.class.normalize_whitespace(p['text']).include?(norm_quote) }
    return { 'id' => matched['id'], 'text' => quote } if matched

    { 'id' => "q-#{Digest::SHA256.hexdigest(norm_quote).first(8)}", 'text' => quote }
  end

  def fallback_evidence_for_doc(doc_id)
    doc = @documents_by_id[doc_id.to_i]
    return unless doc && doc.content.present?

    first_passage = (@passages_by_doc_id[doc.id] || []).first
    return unless first_passage

    {
      'document_id' => doc.id,
      'content_fingerprint' => Digest::SHA256.hexdigest(doc.content.to_s),
      'passage_id' => first_passage['id'],
      'quote' => first_passage['text'].first(QUOTE_MAX_LENGTH),
      'supports' => %w[name purpose]
    }
  end

  def merge_entries(entries)
    grouped = []
    entries.each do |entry|
      existing = grouped.find { |candidate| same_offering?(candidate, entry) }
      existing ? merge_into!(existing, entry) : grouped << entry.deep_dup
    end
    grouped
  end

  def same_offering?(left, right)
    return true if left['id'] == right['id']
    return false unless left['kind'] == right['kind']

    left_names = ([left['name']] + Array(left['aliases'])).map { |n| self.class.canonical_key(n) }.reject(&:blank?)
    right_names = ([right['name']] + Array(right['aliases'])).map { |n| self.class.canonical_key(n) }.reject(&:blank?)
    left_names.intersect?(right_names)
  end

  def merge_into!(target, source)
    target['aliases'] = merged_aliases(target, source)
    %w[category_ids audiences].each do |field|
      target[field] = (Array(target[field]) + Array(source[field])).uniq
    end
    target['evidence'] = (Array(target['evidence']) + Array(source['evidence'])).uniq do |ev|
      [ev['document_id'], ev['passage_id'], ev['quote']]
    end
  end

  def merged_aliases(target, source)
    (Array(target['aliases']) + [source['name']] + Array(source['aliases']))
      .uniq
      .reject { |alias_name| alias_name.casecmp?(target['name']) }
  end

  def apply_overlays(entries)
    result = entries.map { |entry| apply_single_overlay(entry) }
    append_unmatched_overlays(result)
  end

  def apply_single_overlay(entry)
    overlay = @existing_overlays[entry['id']]
    return entry unless overlay

    evidence_changed = overlay_evidence_changed?(overlay, entry)
    merged = entry.dup
    apply_owner_edits!(merged, overlay) if overlay['edited'] == true || overlay['status'] == 'owner_edited'
    apply_overlay_status!(merged, overlay, evidence_changed)
    merged['evidence_changed'] = true if evidence_changed
    merged
  end

  def apply_owner_edits!(merged, overlay)
    merged['name'] = overlay['name'] if overlay['name'].present?
    merged['kind'] = overlay['kind'] if OFFERING_KINDS.include?(overlay['kind'])
    merged['purpose'] = overlay['purpose'] if overlay['purpose'].present?
    %w[aliases category_ids audiences].each do |field|
      merged[field] = overlay[field] if overlay[field].is_a?(Array)
    end
    merged['edited'] = true
    merged['status'] = 'owner_edited'
  end

  def apply_overlay_status!(merged, overlay, evidence_changed)
    if overlay['status'] == 'rejected'
      merged['status'] = evidence_changed ? 'review' : 'rejected'
    elsif overlay['status'].present? && merged['status'] != 'owner_edited'
      merged['status'] = overlay['status']
    end
  end

  def append_unmatched_overlays(result)
    @existing_overlays.each_value do |overlay|
      next unless unmatched_preserved_overlay?(overlay, result)

      valid_ev = Array(overlay['evidence']).select { |ev| self.class.evidence_supported?(ev, @documents_by_id[ev['document_id'].to_i]) }
      result << overlay.merge('evidence' => valid_ev) if valid_ev.any?
    end
    result
  end

  def unmatched_preserved_overlay?(overlay, result)
    (overlay['edited'] == true || overlay['status'].in?(%w[owner_edited rejected])) &&
      result.none? { |e| e['id'] == overlay['id'] }
  end

  def overlay_evidence_changed?(overlay, current)
    old_fingerprints = Array(overlay['evidence']).map { |ev| [ev['document_id'], ev['content_fingerprint']] }.sort
    new_fingerprints = Array(current['evidence']).map { |ev| [ev['document_id'], ev['content_fingerprint']] }.sort
    old_fingerprints.any? && old_fingerprints != new_fingerprints
  end
end

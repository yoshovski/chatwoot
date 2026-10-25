class Captain::KnowledgeBrief < ApplicationRecord # rubocop:disable Metrics/ClassLength
  self.table_name = 'captain_knowledge_briefs'
  EXAMPLE_DOCUMENTS = 30
  EXAMPLES_VERSION = 4
  PRIMARY_OFFERING_KINDS = %w[product service].freeze
  # New agents and unpublished briefs change quickly; settled agents refresh their examples at most monthly.
  EXAMPLES_SETTLING_AGE = 14.days
  EXAMPLES_SETTLING_INTERVAL = 1.hour
  EXAMPLES_SETTLED_INTERVAL = 30.days
  # Automatic profile refreshes slow down as an agent settles: every 3 hours on its first day, daily in its first
  # week, then weekly. Each runs only when knowledge changed since the last draft, or to retry a failed one.
  REFRESH_INTERVALS = { 1.day => 3.hours, 7.days => 1.day }.freeze
  SETTLED_REFRESH_INTERVAL = 7.days

  belongs_to :account
  belongs_to :assistant, class_name: 'Captain::Assistant'
  before_validation -> { self.account = assistant.account if assistant }
  validates :status, inclusion: { in: %w[idle queued generating ready failed] }

  def source_scope
    scope = assistant.documents.enabled.available.where(agents_only: false).where.not(content: [nil, ''])
    return scope unless account.dify_knowledge_enabled?

    scope.where("metadata->>'dify_indexing_status' = 'completed'")
  end

  def fingerprint(ids)
    rows = source_scope.where(id: ids).order(:id).pluck(:id, :name, Arel.sql('md5(content)'))
    return unless rows.size == ids.uniq.size && rows.any?

    Digest::SHA256.hexdigest(rows.to_json)
  end

  def corpus_fingerprint
    rows = source_scope.order(:id).pluck(:id, :name, Arel.sql('md5(content)'))
    Digest::SHA256.hexdigest(rows.to_json)
  end

  def permitted_documents(ids = nil)
    scope = assistant.documents.enabled.where(agents_only: false)
    scope = scope.where(id: ids) if ids
    scope
  end

  def references_document?(snapshot, document_id)
    return false unless snapshot.is_a?(Hash)
    return true if Array(snapshot['document_ids']).include?(document_id)

    Array(snapshot['offerings']).any? do |offering|
      Array(offering['evidence']).any? { |ev| ev['document_id'].to_i == document_id.to_i }
    end
  end

  # Approved text stays in use while the overview still has valid permitted support.
  # Individual topics/offerings whose sources are removed or made private are filtered out immediately at read time.
  def usable?(snapshot)
    return false unless snapshot.is_a?(Hash)

    ids = snapshot['document_ids']
    return false unless ids.is_a?(Array) && ids.any?

    permitted_ids = permitted_documents(ids).pluck(:id)
    return false if permitted_ids.empty?

    overview_ids = Array(snapshot.dig('overview', 'document_ids')).presence || ids
    overview_ids.intersect?(permitted_ids)
  end

  def current?(snapshot)
    return false unless snapshot.is_a?(Hash)

    ids = snapshot['document_ids']
    return false unless ids.is_a?(Array) && ids.any? && snapshot['source_fingerprint'].present?
    return false unless fingerprint(ids) == snapshot['source_fingerprint']

    snapshot['corpus_fingerprint'].blank? || snapshot['corpus_fingerprint'] == corpus_fingerprint
  end

  def usable_topics(snapshot)
    return [] unless snapshot.is_a?(Hash)

    topics = Array(snapshot['topics'])
    return [] if topics.empty?

    all_ids = topics.flat_map { |topic| Array(topic['document_ids']) }.uniq
    permitted = permitted_documents(all_ids).pluck(:id)
    topics.filter_map do |topic|
      valid_ids = Array(topic['document_ids']) & permitted
      topic.merge('document_ids' => valid_ids) if valid_ids.any?
    end
  end

  def usable_offerings(snapshot)
    offerings = snapshot.is_a?(Hash) ? Array(snapshot['offerings']) : []
    return [] if offerings.empty?

    docs_by_id = load_offering_documents(offerings)
    offerings.filter_map { |offering| verify_usable_offering(offering, docs_by_id) }
  end

  def usable_suggestion_candidates(snapshot)
    return [] unless snapshot.is_a?(Hash)

    active_offerings = usable_offerings(snapshot)
    active_topics = usable_topics(snapshot)
    raw = Array(snapshot['suggestion_candidates']).presence ||
          Captain::Knowledge::OfferingReconciler.build_suggestion_candidates(active_offerings, active_topics)
    filter_usable_candidates(raw, active_offerings, active_topics)
  end

  def coverage_summary(snapshot = nil)
    target = snapshot || (published.presence || draft).to_h
    stored = target['coverage'].is_a?(Hash) ? target['coverage'] : {}
    eligible_count = source_scope.count
    counts = assistant.document_analyses.where(document_id: source_scope.select(:id)).group(:status).count
    build_coverage_payload(eligible_count, counts, stored)
  end

  def prompt_context
    return {} unless usable?(published)

    permitted_ids = permitted_documents(published.fetch('document_ids', [])).pluck(:id)
    overview = published.fetch('overview')
    overview_docs = Array(overview['document_ids']) & permitted_ids
    {
      business_overview: overview.merge('document_ids' => overview_docs),
      topic_summaries: usable_topics(published),
      offerings: usable_offerings(published),
      suggestion_candidates: usable_suggestion_candidates(published)
    }
  end

  def examples_input
    snapshot = usable?(published) ? published : draft
    active_names = Array(snapshot['offerings']).reject { |o| o['status'] == 'rejected' }.pluck('name')
    {
      name: assistant.name, product_name: assistant.config['product_name'], description: assistant.description,
      business_type: assistant.effective_business_type,
      overview: snapshot.dig('overview', 'text'), topics: Array(snapshot['topics']).pluck('title'),
      offerings: active_names,
      documents: recent_example_documents
    }
  end

  # Bumping EXAMPLES_VERSION regenerates every agent's examples, at the settling pace, after a prompt change.
  def examples_fingerprint(input = examples_input) = Digest::SHA256.hexdigest([EXAMPLES_VERSION, input].to_json)

  # Regenerates only when the business details changed and the last request is older than the interval.
  # A save by the owner (refresh) skips the interval, so previews follow what they just changed.
  def examples_due?(refresh: false)
    return false if examples['fingerprint'] == examples_fingerprint
    return true if refresh

    requested_at = examples['requested_at']
    requested_at.nil? || Time.zone.parse(requested_at) < examples_interval.ago
  end

  def examples_interval
    settling = assistant.created_at > EXAMPLES_SETTLING_AGE.ago || !usable?(published) || examples['version'] != EXAMPLES_VERSION
    settling ? EXAMPLES_SETTLING_INTERVAL : EXAMPLES_SETTLED_INTERVAL
  end

  def refresh_due?
    interval = refresh_interval
    return updated_at < interval.ago if status == 'failed'
    return false if generated_at&.after?(interval.ago)

    scope = source_scope
    generated_at ? scope.exists?(['captain_documents.updated_at > ?', generated_at]) : scope.exists?
  end

  def refresh_interval
    age = Time.current - assistant.created_at
    REFRESH_INTERVALS.find { |limit, _interval| age < limit }&.last || SETTLED_REFRESH_INTERVAL
  end

  def client_payload
    as_json(only: %i[status draft published error_code generated_at]).merge(
      'enabled' => assistant.config['knowledge_brief_enabled'] == true,
      'recoverable' => status.in?(%w[queued generating]) && updated_at < 20.minutes.ago,
      'draft_usable' => usable?(draft), 'published_usable' => usable?(published),
      'sources_changed' => usable?(published) && !current?(published),
      'coverage' => coverage_summary,
      'sources' => source_scope.order(:name).pluck(:id, :name, :external_link).map do |id, name, url|
        { id: id, name: name, url: url, section: Captain::Documents::Sections.key_for(url) }
      end
    )
  end

  private

  def recent_example_documents
    source_scope.order(updated_at: :desc).limit(EXAMPLE_DOCUMENTS).pluck(:id, :name).map { |id, name| { id: id, title: name } }
  end

  def load_offering_documents(offerings)
    doc_ids = offerings.flat_map { |item| Array(item['evidence']).map { |ev| ev['document_id'].to_i } }.uniq
    permitted_documents(doc_ids).index_by(&:id)
  end

  def verify_usable_offering(offering, docs_by_id)
    return unless offering.is_a?(Hash) && offering['status'] != 'rejected'

    supported_ev = Array(offering['evidence']).select do |ev|
      Captain::Knowledge::OfferingReconciler.evidence_supported?(ev, docs_by_id[ev['document_id'].to_i])
    end
    return if supported_ev.empty?

    offering.merge('evidence' => supported_ev, 'document_ids' => supported_ev.pluck('document_id').uniq)
  end

  def filter_usable_candidates(raw_candidates, active_offerings, active_topics)
    return [] if raw_candidates.empty?

    offering_ids = active_offerings.to_set { |item| item['id'] }
    primary_count = active_offerings.count { |item| PRIMARY_OFFERING_KINDS.include?(item['kind']) }
    doc_ids = raw_candidates.flat_map { |item| Array(item['document_ids']).map(&:to_i) }.uniq
    permitted_doc_ids = permitted_documents(doc_ids).pluck(:id).to_set

    raw_candidates.select do |candidate|
      candidate_usable?(candidate, offering_ids, primary_count, permitted_doc_ids, active_offerings.any? || active_topics.any?)
    end
  end

  def candidate_usable?(candidate, offering_ids, primary_count, permitted_doc_ids, has_content)
    return false unless valid_candidate_target?(candidate, offering_ids, primary_count)

    cand_docs = Array(candidate['document_ids']).map(&:to_i)
    cand_docs.empty? ? has_content : cand_docs.any? { |id| permitted_doc_ids.include?(id) }
  end

  def valid_candidate_target?(candidate, offering_ids, primary_count)
    return false unless candidate.is_a?(Hash) && candidate['title'].present? && candidate['message'].present?
    return false if candidate['target_kind'] == 'offering' && offering_ids.exclude?(candidate['target_id'])

    candidate['target_id'] != 'all-offerings' || primary_count > 1
  end

  def build_coverage_payload(eligible_count, counts, stored)
    resolved = resolve_coverage_counts(eligible_count, counts, stored)
    latest_run = assistant.knowledge_analysis_runs.order(created_at: :desc).first
    resolved.merge(
      'scope' => 'approved-eligible-documents',
      'corpus_fingerprint' => corpus_fingerprint,
      'discovered_pages' => assistant.website_sources.sum { |ws| Array(ws.pages).size },
      'budget_stopped' => latest_run&.status == 'budget_stopped' || stored['budget_stopped'] == true
    )
  end

  def resolve_coverage_counts(eligible_count, counts, stored)
    processed = counts['analyzed'] || stored['processed'].to_i
    partial = counts['partial'] || stored['partial'].to_i
    failed = counts['failed'] || stored['failed'].to_i
    excluded = counts['excluded'] || stored['excluded'].to_i
    stale = counts['stale'].to_i
    pending = [eligible_count - (processed + partial + failed + excluded + stale), counts['pending'].to_i, 0].max
    {
      'eligible' => eligible_count, 'processed' => processed, 'partial' => partial,
      'pending' => pending, 'failed' => failed, 'excluded' => excluded, 'stale' => stale
    }
  end
end
